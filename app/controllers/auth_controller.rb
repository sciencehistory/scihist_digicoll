class AuthController < Devise::OmniauthCallbacksController

  # This method signs a user in after they authenticate with Microsoft Azure.
  def azure_activedirectory_v2
    final_sign_in request.env['omniauth.auth']['info']['email']
  end

  # Allows a developer to sign on without using OAuth.
  def dev_login
    if ScihistDigicoll::Env.staging? || ScihistDigicoll::Env.production?
      flash[:alert] = "Can't log you in this way."
      redirect_back(fallback_location: root_path)
      return
    end
    dev_login = ScihistDigicoll::Env.lookup(:dev_login)
    unless dev_login =~URI::MailTo::EMAIL_REGEXP
      flash[:alert] = "Please set DEV_LOGIN to a valid email address."
      redirect_back(fallback_location: root_path)
      return
    end
    final_sign_in dev_login
  end

  private

  # We need to provide a default path for newly signed-in users.
  # Usual login paths do not call this method, but when
  # the SSO setup is misconfigured
  # this method does sometimes get called, resulting in a 500 error.
  # Instead, we send users to the root path.
  def new_session_path  *args
    flash[:notice] = "This URL is not meant for regular users."
    root_path
  end

  # Look up a user. If they're not locked out, sign them in.
  def final_sign_in(email)
    @user = User.where('email ILIKE ?', "%#{ User.sanitize_sql_like(email) }%").first
    if @user&.persisted?
      if @user.locked_out?
        flash[:alert] = "Sorry, this user is not allowed to log in."
        redirect_back(fallback_location: root_path)
        return
      else
        flash[:notice] = 'Signed in successfully.'
        sign_in_and_redirect @user, event: :authentication
        return
      end
    else
      flash[:alert] = "We couldn't find an account for you. Please contact an administrator."
      redirect_back(fallback_location: root_path)
      return
    end
  end
end
