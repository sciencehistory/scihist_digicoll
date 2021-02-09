class OralHistoryRequestNotificationMailer < ApplicationMailer
  def notification_email
    @oral_history_request = params[:request]
    mail(to: ScihistDigicoll::Env.lookup(:oral_history_email_address), subject: 'Oral History Access Request')
  end
end
