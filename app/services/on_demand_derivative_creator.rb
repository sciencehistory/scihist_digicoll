# Responsible for creating OnDemandDerivative models, launching bg jobs
# to actually create the derivatives, and updating status in the OnDemandDerivative
# model.
#
# Does this all using careful atomic SQL, to ensure that only one process will be trying to create
# an on-demand-derivative at a time, wont' have two of them both deciding that one doesn't exist yet
# and needs to be created and trying to create.
#
# Will look at all members to determine inputs_checksum, so if you're doing a lot at once members should
# be pre-loaded to avoid n+1. (But we don't normally do a lot at once, it's normally one at a time on demand
# from OnDemandDerivativeController)
class OnDemandDerivativeCreator
  MAX_RETRY_COUNT = 10
  STALE_IN_PROGRESS_SECONDS = 20.minutes
  ERROR_RETRY_SECONDS = 10.minutes

  attr_reader :work, :derivative_type

  def initialize(work, derivative_type:)
    unless OnDemandDerivative.derivative_type_definitions.keys.include?(derivative_type.to_sym)
      raise ArgumentError.new("unrecognized derivative type: #{derivative_type}")
    end

    @work = work
    @derivative_type = derivative_type
  end

  # Will return an OnDemandDerivative record, which could be in an in_progress, success,
  # or error stage.
  #
  # If it's in a success state, we checked it to make sure there really is a derivative available
  # at on_demand_derivative.file_url
  #
  # If it's in an in_progress state, that *may* mean we just set it to that state here, and
  # kicked off an OnDemandDeriativeCreatorJob to actually create the derivative file in the bg.
  #
  # We take care of all of this in a concurrency-safe way, so we should never kick off a bg job
  # if there's another one in progress (unless it's been marked in progress for longer than
  # STALE_IN_PROGRESS_SECONDS)
  #
  # This method is normally called from the OnDemandDerivativeController, and
  # returns an OnDemandRecord whose json representation is normally returned from that controller.
  #
  # @param retry_count [Integer] used for limiting recursive calls, shouldn't
  #   really be passed in by caller, let it default to 0 for external callers.
  def find_or_create_record(retry_count: 0)
    if retry_count > MAX_RETRY_COUNT
      # what the heck is going on? Let's keep us from infinitely doing it and taking up all the CPU
      raise StandardError.new("Tried to find/create an OnDemandDerivative record too many times for work #{id}")
    end

    record = OnDemandDerivative.where(work_id: work.id, deriv_type: derivative_type).first

    # No record? We have to register one as in_progress so nobody else will, and launch the bg job
    if record.nil?
      # If someone else concurrently created, should raise when we try to make a second one.
      record = OnDemandDerivative.create!(work_id: work.id, deriv_type: derivative_type, status: :in_progress, inputs_checksum: calculated_checksum)
      OnDemandDerivativeCreatorJob.perform_later(work, derivative_type)
    end

    # have a record? Is it stale?
    if stale?(record)
      # delete it, and try the whole thing again
      record.delete
      record = find_or_create_record(type, retry_count: retry_count + 1)
    end

    return record
  rescue ActiveRecord::RecordNotUnique
    # race condition, someone else created it, no biggy, just try again
    return find_or_create_record(type, retry_count: retry_count + 1)
  end

  # Given an OnDemandDerivative record, in an in_progress state, we will
  # actually create the relevant derivative file (inline NOT in bg), and
  # then set the OnDemandDerivative to a success state.
  #
  # The on_demand_derivative instance will have it's progress and progress_total
  # values updated periodically.
  #
  # This method could take a while, and is normally called from the OnDemandDerivativeJob.
  #
  # It will create a new derivative file in storage even if one already exists, overwriting it.
  #
  # It's up to the caller to make sure not to call this more than once concurrently,
  # only calling it if caller was the one that set status to "in_progress" with
  # an atomic update. Normally this is called by a bg job started by #find_or_create_record,
  # which has such logic.
  #
  # @param on_demand_derivative [OnDemandDerivative]
  def attach_derivative!
    on_demand_derivative = OnDemandDerivative.find_by(work_id: work.id, deriv_type: derivative_type, status: "in_progress")

    unless on_demand_derivative
      raise ArgumentError.new("In order to #attach_derivative! we need an exising OnDemandDerivative with work_id: #{work.id}, deriv_type: #{derivative_type}, status: in_progress. But none found.")
    end

    creator_class = on_demand_derivative.deriv_type_definition[:creator_class_name].constantize

    callback = lambda do |progress_i:, progress_total:|
      on_demand_derivative.update(progress: progress_i, progress_total: progress_total)
    end

    creator = creator_class.new(work, callback: callback)

    derivative = creator.create
    on_demand_derivative.put_file(derivative)

    on_demand_derivative.update(status: "success", inputs_checksum: calculated_checksum)
  rescue StandardError => e
    if on_demand_derivative
      on_demand_derivative.update(status: "error", error_info: {class: e.class.name, message: e.message, backtrace: e.backtrace}.to_json)
    end
    raise e
  ensure
    if derivative
      derivative.close
      derivative.unlink
    end
  end

  # In progress, but so old we want to give up on it?
  # Error, and so old we want to try again?
  # Success, but for a different inputs_checksum?
  # Success, but file doesn't actually exist in (S3) storage?
  #
  # Any of those, we consider it stale.
  def stale?(record)
    ( record.in_progress? && (Time.now - record.updated_at) > STALE_IN_PROGRESS_SECONDS ) ||
    ( record.error? && (Time.now - record.updated_at) > ERROR_RETRY_SECONDS ) ||
    ( record.success? && (record.inputs_checksum !=  calculated_checksum || !record.file_exists? ))
  end

  # The checksum represents the state of the work, and is attacched to a created derivative.
  # If the checksum for an existing created derivative doesn't match current checksum, we know
  # the existing created derivative is stale and doens't match current work state.
  #
  # We calculate checksum based on file MD5's for _all_ members, so if any members are added/removed/changed,
  # it will change the checksum. this is more aggressive than it needs to be, since some members (non-published
  # for instance) may not be a part of a given derivative, but rather than try to fit it just right to the given
  # derivative, we just take a wide brush to make sure it will never use a bad derivative, although may sometimes
  # consider stale one that could have been good.
  #
  # Our current derivatives only use the single representative of a child work, so our checksum does too.
  def calculated_checksum
    @calculated_checksum ||= begin
      individual_checksums = work.members.includes(:leaf_representative).collect do |m|
        m.leaf_representative&.md5
      end.compact

      parts = [work.title, work.friendlier_id] + individual_checksums

      Digest::MD5.hexdigest(parts.join("-"))
    end
  end

end
