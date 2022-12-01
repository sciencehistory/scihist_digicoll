class Work < Kithe::Work
  include AttrJson::Record::QueryScopes

  # will trigger automatic solr indexing in callbacks

  include RecordPublishedAt

  if ScihistDigicoll::Env.lookup(:solr_indexing) == 'true'
    self.kithe_indexable_mapper = WorkIndexer.new
  end

  # pre-loads associations you need to pre-load to do bulk-indexing of multiple works without
  # n+1 queries -- that is with Rails `strict_loading` on and without errors. That is, associations
  # the WorkIndexer is going to want.  Often used with `strict_loading`.
  scope :for_batch_indexing, -> { includes(:contains_contained_by, :members, :oral_history_content => :interviewee_biographies) }

  # for now forbid 'role' for Work, we only use it for asset
  validates :role, absence: true

  belongs_to :digitization_queue_item, optional: true, class_name: "Admin::DigitizationQueueItem"

  has_many :on_demand_derivatives, inverse_of: :work, dependent: :destroy
  has_many :oral_history_access_requests, inverse_of: :work, dependent: :destroy, class_name: "Admin::OralHistoryAccessRequest"


  has_many :cart_items, dependent: :delete_all


  has_one :oral_history_content, inverse_of: :work, dependent: :destroy

  validates :external_id, presence: true
  validates :department, inclusion: { in: ControlledLists::DEPARTMENT, allow_blank: true }
  validates :file_creator, inclusion: { in: ControlledLists::FILE_CREATOR, allow_blank: true }
  validates :rights, inclusion: { in: RightsTerm.all_ids, allow_blank: true }
  validates :format, array_inclusion: { in: ControlledLists::FORMAT }
  validates :genre, array_inclusion: { in: ControlledLists::GENRE  }
  validates :exhibition, array_inclusion: { in: ControlledLists::EXHIBITION  }
  validates :related_url, array_inclusion: {
    proc: ->(v) { ScihistDigicoll::Util.valid_url?(v) } ,
    message: "is not a valid url: %{rejected_values}"
  }

  with_options if: :published?, message: "can't be blank for published works" do |work|
    work.validates_presence_of :date_of_work
    work.validates_presence_of :format
    work.validates_presence_of :genre
    work.validates_presence_of :department
    work.validates_presence_of :rights
  end

  attr_json :additional_title, :string, array: true, default: -> { [] }
  attr_json :external_id, Work::ExternalId.to_type, array: true, default: -> { [] }
  attr_json :creator, Work::Creator.to_type, array: true, default: -> { [] }
  attr_json :date_of_work, Work::DateOfWork.to_type, array: true, default: -> { [] }
  attr_json :place, Work::Place.to_type, array: true, default: -> { [] }
  attr_json :format, :string, array: true, default: -> { [] }
  attr_json :genre, :string, array: true, default: -> { [] }
  attr_json :medium, :string, array: true, default: -> { [] }
  attr_json :extent, :string, array: true, default: -> { [] }
  attr_json :language, :string, array: true, default: -> { [] }
  attr_json :description, :text
  attr_json :provenance, :text
  attr_json :inscription, Work::Inscription.to_type, array: true, default: -> { [] }

  # eventually keep vocab id?
  attr_json :subject, :string, array: true, default: -> { [] }

  attr_json :department, :string
  attr_json :exhibition, :string, array: true, default: -> { [] }
  attr_json :series_arrangement, :string, array: true, default: -> { [] }
  attr_json :physical_container, Work::PhysicalContainer.to_type

  # legacy :related_url to be replaced with :related_link
  attr_json :related_url, :string, array: true, default: -> { [] }
  attr_json :related_link, RelatedLink.to_type, array: true, default: -> { [] }

  attr_json :rights, :string
  attr_json :rights_holder, :string
  attr_json :additional_credit, Work::AdditionalCredit.to_type, array: true, default: -> { [] }
  attr_json :digitization_funder, :string

  attr_json :file_creator, :string
  attr_json :admin_note, :text, array: true, default: -> { [] }

  # filter out empty strings, makes our forms easier, with the way checkbox
  # groups include hidden field with empty string. Kithe repeatable
  # input normally handles this for us, but we're not using one for this one.
  def format=(arr)
    if arr.is_a?(Array)
      arr = arr.reject {|v| v.blank? }
    end
    super(arr)
  end

  # With one pg recursive CTE find _all_ descendent members, through
  # multiple levels.
  #
  # TODO: Move to kithe? Make more general, a class method that takes
  # IDs?
  def all_descendent_members
    raise TypeError.new("can only call on a persisted object") unless persisted? && id.present?

    sql = <<~EOS
      id IN (WITH RECURSIVE tree AS (
        SELECT id, ARRAY[]::UUID[] AS ancestors
        FROM kithe_models WHERE id = '#{self.id}'

        UNION ALL

        SELECT kithe_models.id, tree.ancestors || kithe_models.parent_id
        FROM kithe_models, tree
        WHERE kithe_models.parent_id = tree.id
      ) SELECT id FROM tree WHERE id != '#{self.id}')
    EOS


    Kithe::Model.where(sql)
  end

  # All DISPLAYABLE (to current user) members, in order, and
  # with proper pre-fetches.
  def ordered_viewable_members(current_user:)


    members = self.members.includes(:leaf_representative)

    access_policy = AccessPolicy.new(current_user)
    show_unpublished = access_policy.can?(:read, Asset) && access_policy.can?(:read, Work)
    members = members.where(published: true) unless show_unpublished
    
    members = members.order(:position)

    # the point of this is to avoid n+1's, so let's set strict_loading, which
    # it turns out you can do on an association/relation
    members = members.strict_loading

    members.to_a
  end

  # Ensures the optional sidecar OralHistoryContent is present if it wans't already
  # (saving to db if receiver is persisted), and returns it.
  #
  # Tries to be concurrency-safe.
  def oral_history_content!
    retries = 0
    begin
      oral_history_content || (
        persisted? ? create_oral_history_content : build_oral_history_content
      )
    rescue ActiveRecord::RecordNotUnique => e
      # concurrent creation, let's try again, but not infinitely...
      self.association(:oral_history_content).reset
      retries += 1
      if retries < 3
        retry
      else
        raise e
      end
    end
  end

  # This method is used by `oai` gem to automatically get serialization for oai-pmh responses
  # @returns [String] XML, note as a STRING.
  def to_oai_dc
    WorkOaiDcSerialization.new(self).to_oai_dc
  end

  # @returns [Array] of IANA/MIME content types from any members.
  #
  # For children that are Works themselves, only includes the content-type of the single
  # represnetative of that work, does not completely descend the hieararchy tree.
  #
  # This is something we need frequently, but is hard to do efficiently! This method provides
  # two modes to do it, you need to choose the mode explicity.
  #
  # @option mode [Symbol], :query or :associaiton.
  #
  # :query will go to the database to execute a single relatievly efficient query to collect
  # these. Great if you are doing it for a single Work, and does not require loading
  # all #members and their #leaf_representatives into memory -- but would be an n+1 query
  # problem if using this mode on a page of works.
  #
  # :association will do an in-memory scan of all #members and their #leaf_representatives.
  # Find if you already have those associations in-memory, but will a terrible n+1
  # (or even n^2+1) query if you don't. :association mode will actually raise a TypeError
  # if you try using it WITHOUT associations pre-loaded, to avoid the dangerous mistake.
  # That is, it wants you to have done: `Work.where(something).includes(members: :leaf_representative)`
  #
  # In either case, answer is memoized/cached on this Work instance, unless you call
  # with `reset: true` to re-fetchc/re-calculate.
  #
  # This is kind of a complicated mess; and the Work model is kind of an architecturally
  # unfortunate place to put this complicated mess, better to segregate in a ViewComponent
  # or something? But this worked for being easily accessible from the various places
  # that needed it (and memoizing it in common), avoiding having to pass it down as
  # an argument along a nested call-chain. Eg DownloadDropdownComponent needs it.
  def member_content_types(mode:, reset: false)
    raise ArgumentError.new("mode must be :query or :association") unless [:query, :association].include?(mode)

    if reset
      @member_content_types = nil
    end

    @member_content_types ||= begin
      if mode == :association
        unless members.loaded?
          raise TypeError.new("Calling member_content_types with mode: :association without pre-loaded members, performance problem")
        end

        members.collect do |member|
          unless member.association(:leaf_representative).loaded?
            raise TypeError.new("Calling member_content_types with mode: :association without pre-loaded members.leaf_representative, performance problem")
          end

          member.leaf_representative&.content_type
        end.compact.uniq
      else # mode == :query
        self.members.
          includes(:leaf_representative).
          references(:leaf_representative).
          pluck(Arel.sql("
            DISTINCT leaf_representatives_kithe_models.file_data -> 'metadata' -> 'mime_type', kithe_models.file_data -> 'metadata' -> 'mime_type'"
          )).flatten.compact.uniq
      end
    end
  end

  # @returns [Integer] count of members (cached)
  #
  # This will keep returning the same number in subsequent times called on the same instance, it's cached.
  #
  # It's really only meant for use in display code, and specifically created for DownloadDropdownDisplay.
  #
  # This is architecturally not a great place to put this, but it works. See also #member_content_types
  def member_count(reset: false)
    @member_count = nil if reset
    @member_count ||= members.size
  end

  # We have enough checks for special treatment of oral history, it makes
  # sense to make a method to encapsulate it.
  def is_oral_history?
    genre && genre.include?("Oral histories")
  end

end
