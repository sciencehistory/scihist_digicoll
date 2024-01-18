# Preview all emails at http://localhost:3000/rails/mailers/oh_session
class OhSessionPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/oh_session/link_email
  def link_email
    requester_email = OralHistoryRequester.create_or_find_by!(email: "example@example.com")

    OhSessionMailer.with(requester_email: ).link_email
  end

end
