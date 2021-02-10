class ApplicationMailer < ActionMailer::Base
  # Note that for delivery TO sciencehistory.org email addresses, if the email
  # is also FROM a @sciencehistory.org address, it needs to be allow-listed
  # by IT to avoid their anti-phishing measures.
  #
  # So be careful with "from" email addresses on Amazon SES-sent emails.
  default from: ScihistDigicoll::Env.lookup!(:no_reply_email_address)

  layout 'mailer'
end
