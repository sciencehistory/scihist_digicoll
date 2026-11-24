# Preview all emails at http://localhost:3000/rails/mailers/oh_session
#
# Each takes optional ?return_to=/some/path, or empty ?return_to= to preview without one.
class OhSessionPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/oh_session/sign_in_email
  def sign_in_email
    OhSessionMailer.with(patron: sample_patron, return_to: sample_return_to).sign_in_email
  end

  # Preview this email at http://localhost:3000/rails/mailers/oh_session/registration_email
  def registration_email
    OhSessionMailer.with(patron: sample_patron, return_to: sample_return_to).registration_email
  end

  private

  def sample_patron
    Patron.create_or_find_by!(email: "example@example.com") { |p| p.name = "Test Patron" }
  end

  def sample_return_to
    params.key?(:return_to) ? params[:return_to].presence : "/works/example"
  end
end
