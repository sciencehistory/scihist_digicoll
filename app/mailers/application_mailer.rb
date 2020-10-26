class ApplicationMailer < ActionMailer::Base
  default from: ScihistDigicoll::Env.lookup!(:digital_email_address)
  layout 'mailer'
end
