class FixityFailureMailer < ApplicationMailer


  def fixity_failure_email
    raise ArgumentError.new("Required params[:fixity_check] missing") unless params[:fixity_check]
    @fixity_check = params[:fixity_check]
    @asset = @fixity_check.asset
    from_address = ScihistDigicoll::Env.lookup(:no_reply_email_address)
    to_address = [
        ScihistDigicoll::Env.lookup(:digital_tech_email_address),
        ScihistDigicoll::Env.lookup(:digital_email_address)
      ].compact.join(',')

    unless from_address.present? && to_address.present?
      raise RuntimeError, 'Cannot send fixity error email; specify at least a "from" and a "to" address.'
    end
    mail(
      from:         from_address,
      to:           to_address,
      subject:      subject,
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

  def asset_url
    @asset_url ||= "#{hostname}#{Rails.application.routes.url_helpers.admin_asset_path(@asset.friendlier_id)}"
  end

  def asset_link
    "<a href=\"#{asset_url}\">#{@asset.title}</a>".html_safe
  end

  def work
    @work ||= @asset&.parent
  end

  def work_url
    @work_url ||= "#{hostname}#{Rails.application.routes.url_helpers.work_path(work.friendlier_id)}"
  end

  def work_link
    "<a href=\"#{work_url}\">#{@work.title}</a>".html_safe
  end
end