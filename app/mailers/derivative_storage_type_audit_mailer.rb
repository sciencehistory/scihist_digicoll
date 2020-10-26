class DerivativeStorageTypeAuditMailer < ApplicationMailer

  def audit_failure_email
    raise ArgumentError.new("Required params[:asset_derivative_storage_type_auditor] missing") unless params[:asset_derivative_storage_type_auditor]
    @auditor = params[:asset_derivative_storage_type_auditor]

    to_address = [
        ScihistDigicoll::Env.lookup(:digital_tech_email_address),
        ScihistDigicoll::Env.lookup(:digital_email_address)
      ].compact.join(',')

    unless to_address.present?
      raise RuntimeError, 'Cannot send fixity error email; specify a "to" address.'
    end

    mail(
      to:           to_address,
      subject:      "Digital Collections Warning: #{hostname}: Assets with unexpected derivative_storage_type state found",
      content_type: "text/html",
    )
  end

end
