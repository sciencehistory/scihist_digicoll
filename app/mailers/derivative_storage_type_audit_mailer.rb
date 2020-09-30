class DerivativeStorageTypeAuditMailer < ApplicationMailer

  def audit_failure_email
    raise ArgumentError.new("Required params[:asset_derivative_storage_type_auditor] missing") unless params[:asset_derivative_storage_type_auditor]
    @auditor = params[:asset_derivative_storage_type_auditor]

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
      subject:      "Digital Collections Warning: #{hostname}: Assets with unexpected derivative_storage_type state found",
      content_type: "text/html",
    )
  end


  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end
end
