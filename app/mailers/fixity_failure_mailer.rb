#class FixityFailureMailer < ApplicationMailer

class FixityFailureMailer < ApplicationMailer

  def fixity_failure_email
    @fixity_check = params[:fixity_check]
    @asset = @fixity_check.asset
    from_address = ScihistDigicoll::Env.lookup(:no_reply_email_address)
    to_address   = ScihistDigicoll::Env.lookup(:digital_tech_email_address)
    if from_address.nil? || to_address.nil?
      raise RuntimeError, 'Cannot send fixity error email; no email address is defined.'
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
end