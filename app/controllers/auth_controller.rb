class AuthController < Devise::OmniauthCallbacksController

  # This method signs a user in after they authenticate with Microsoft Azure.
  def azure_activedirectory_v2
    unless ScihistDigicoll::Env.lookup(:log_in_using_azure)
      flash[:alert] = "Sorry, you can't log in this way."
      redirect_back(fallback_location: root_path)
      return
    end

    email = request.env['omniauth.auth']['info']['email']
    @user = User.where('email ILIKE ?', "%#{ User.sanitize_sql_like(email) }%").first

    unless @user&.persisted?
      flash[:alert] = "You can't currently log in to the Digital Collections. Please contact a Digital Collections administrator."
      redirect_back(fallback_location: root_path)
      return
    end

    if @user.locked_out?
      flash[:alert] = "Sorry, this user is not allowed to log in."
      redirect_back(fallback_location: root_path)
      return
    end

    flash[:notice] = 'Signed in successfully.'
    sign_in_and_redirect @user, event: :authentication
  end


  private

  # We need to provide a default path for newly signed-in users.
  # Usual login paths do not call this method, but when
  # the SSO setup is misconfigured,
  # this method does sometimes get called, resulting in a 500 error.
  # Instead, we send users to the root path.
  def new_session_path  *args
    flash[:notice] = "This URL is not meant for regular users."
    root_path
  end
end
