class ApplicationMailer < ActionMailer::Base
  default from: (ScihistDigicoll::Env.lookup(:no_reply_email_address) || "from@example.com")
  layout 'mailer'
end
