class ApplicationMailer < ActionMailer::Base
  default from: ScihistDigicoll::Env.lookup!(:digital_email_address)
  layout 'mailer'


  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

end
