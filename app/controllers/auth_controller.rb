class AuthController < Devise::OmniauthCallbacksController


  def azure_activedirectory_v2
    final_sign_in request.env['omniauth.auth']['info']['email']
  end

  def dev_login
    if ScihistDigicoll::Env.staging? || ScihistDigicoll::Env.production?
      flash[:alert] = "Can't log you in this way."
      redirect_back(fallback_location: root_path)
      return
    end
    dev_login = ScihistDigicoll::Env.lookup(:dev_login)
    if dev_login.nil?
      flash[:alert] = "To log in this way, please make sure you have the ENV variable DEV_LOGIN set to your email address."
      redirect_back(fallback_location: root_path)
      return
    end
    final_sign_in dev_login
  end


  def new_session_path  *args
    flash[:notice] = "This URL is not meant for regular users."
    root_path
  end

  private

  def final_sign_in(email)
    @user = User.where('email ILIKE ?', "%#{ User.sanitize_sql_like(email) }%").first
    if @user&.persisted?
      flash[:notice] = 'Signed in successfully.'
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "We couldn't find an account for you. Please contact an administrator."
      redirect_back(fallback_location: root_path)
      return
    end
  end
end
