# Preview all emails at http://localhost:3000/rails/mailers/oh_session
class OhSessionPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/oh_session/sign_in_email
  def sign_in_email
    patron = Patron.create_or_find_by!(email: "example@example.com") { |p| p.name = "Test Patron" }

    OhSessionMailer.with(patron: ).sign_in_email
  end

  # Preview this email at http://localhost:3000/rails/mailers/oh_session/registration_email
  def registration_email
    patron = Patron.create_or_find_by!(email: "example@example.com") { |p| p.name = "Test Patron" }
    work = Work.joins(:oral_history_content).
      where(oral_history_content: { availability_mode: "automatic_request" }).first ||
      (raise TypeError.new("need an automatic_request oral history in db to preview"))

    OhSessionMailer.with(patron:, work:).registration_email
  end

end
