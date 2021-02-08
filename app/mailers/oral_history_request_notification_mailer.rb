class OralHistoryRequestNotificationMailer < ApplicationMailer
  def notification_email
    @oral_history_request = params[:request]
    mail(to: ScihistDigicoll::Env.fetch!(:oral_history_email_address), subject: 'Oral History Request')
  end
end
