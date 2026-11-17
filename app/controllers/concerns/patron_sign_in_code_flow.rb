# After emailing a patron a sign-in link and code, shows the form to enter the code: in the
# modal for xhr, otherwise as a page. The code is checked against the email kept in session.
module PatronSignInCodeFlow
  # you can only use succesfully use a code in a session that has the corresponding
  # email address saved, for security we can't just check the code against all users.
  SESSION_KEY = :patron_sign_in_code_email

  private

  def show_sign_in_code_form(patron, message:, return_to: nil)
    session[SESSION_KEY] = patron.email

    if request.xhr?
      render partial: "oral_history_sessions/code_modal", layout: false, locals: { message: message, return_to: return_to }
    else
      redirect_to code_oral_history_session_path(return_to: return_to), flash: { success: message }
    end
  end
end
