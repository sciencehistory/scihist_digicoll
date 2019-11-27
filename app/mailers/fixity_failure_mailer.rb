class FixityFailureMailer < ApplicationMailer

  def fixity_failure_email
    @fixity_check = params[:fixity_check]
    @asset = @fixity_check.asset
    from_address = ScihistDigicoll::Env.lookup(:no_reply_email_address)
    to_address   = ScihistDigicoll::Env.lookup(:digital_tech_email_address)
    if from_address.nil? || to_address.nil?
      raise RuntimeError, 'Cannot send fixity error email; no email address is defined.'
    end

    puts from_address
    puts to_address

    mail(
      from:    from_address,
      to:      to_address,
      subject: subject,
      content_type: "text/html",
      )
  end

  def subject
    "FIXITY CHECK FAILURE: #{ScihistDigicoll::Env.lookup!(:app_url_base)}, \"#{@asset.title}\" (asset #{@asset.friendlier_id})"
  end

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