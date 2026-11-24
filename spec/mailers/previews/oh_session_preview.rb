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

    OhSessionMailer.with(patron:, return_to: "/works/example").registration_email
  end

end
