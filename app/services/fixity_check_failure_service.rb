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
    FixityFailureMailer.
      with(fixity_check: @fixity_check).
      fixity_failure_email
      .deliver_now

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

  def asset_url
    @asset_url ||= "#{ScihistDigicoll::Env.lookup!(:app_url_base)}#{Rails.application.routes.url_helpers.admin_asset_path(@asset.friendlier_id)}"
  end
end
