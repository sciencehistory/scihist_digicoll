class ApplicationMailer < ActionMailer::Base
  default from: (ScihistDigicoll::Env.lookup(:digital_collections_email_address) || "from@example.com")
  layout 'mailer'
end
