class FixityCheckFailureService
  include ActionView::Helpers::UrlHelper

  attr_reader :fixity_check

  def initialize(fixity_check)
    raise ArgumentError.new("Fixity check passed was nil.") if fixity_check.nil?
    raise ArgumentError.new("Please pass in a FixityCheck.") unless fixity_check.is_a? FixityCheck
    @fixity_check = fixity_check
    @asset = fixity_check.asset
  end


  def send
    from_address = ScihistDigicoll::Env.lookup!(:no_reply_email_address)
    to_address   = ScihistDigicoll::Env.lookup!(:digital_tech_email_address)
    if from_address.nil? || to_address.nil?
      raise RuntimeError, 'Cannot send fixity error email; no email address is defined.'
    else
      ActionMailer::Base.mail(from:    from_address,
                              to:      to_address,
                              subject: subject,
                              content_type: "text/html",
                              body: message).deliver_later
    end

    if defined? Honeybadger
      Honeybadger.notify("Fixity check failure: #{@asset.friendlier_id}",
        context: {
          asset: @asset.inspect,
          asset_url: asset_url,
          fixity_check: @fixity_check.inspect
        },
        fingerprint: "fixity_check_failure_#{@asset.friendlier_id}",
        tags: "fixity"
      )
    end
  end

  def subject
    "FIXITY CHECK FAILURE: #{ScihistDigicoll::Env.lookup!(:app_url_base)}, \"#{@asset.title}\" (asset #{@asset.friendlier_id})"
  end

  def message
    <<-EOF
    <p>A fixity check for asset #{@asset.friendlier_id} on #{hostname} just failed at #{ date }.</p>
    <dt>Asset:</dt><dd>#{asset_message}</dd>
    <dt>Work:</dt><dd>#{work_message}</dd>
    <dt>Failing FixityCheck id:</dt><dd>#{ @fixity_check.id }</dd>
    <dt>Time:</dt><dd>#{ date }</dd>
    <dt>Expected #{ @fixity_check.hash_function }:</dt><dd> #{fixity_check.expected_result}</dd>
    <dt>Actual #{ @fixity_check.hash_function }:</dt><dd>#{ @fixity_check.actual_result}</dd>
    <dt>Checked file location</dt><dd>#{link_to_if @fixity_check.checked_uri_in_s3_console, @fixity_check.checked_uri, @fixity_check.checked_uri_in_s3_console }</dd>
    EOF
  end

  protected

  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def date
    I18n.l @fixity_check.created_at, format: :admin
  end

  def work
    @work ||= @asset&.parent
  end

  def asset_message
    "<a href=\"#{asset_url}\">#{@asset.title}</a>"
  end

  def work_message
    return "(none)" if work.nil?
    "<a href=\"#{work_url}\">#{@work.title}</a>"
  end

  def work_url
    @work_url ||= "#{ScihistDigicoll::Env.lookup!(:app_url_base)}#{Rails.application.routes.url_helpers.work_path(work.friendlier_id)}"
  end

  def asset_url
    @asset_url ||= "#{ScihistDigicoll::Env.lookup!(:app_url_base)}#{Rails.application.routes.url_helpers.admin_asset_path(@asset.friendlier_id)}"
  end
end
