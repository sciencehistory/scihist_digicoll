class AuthController < Devise::OmniauthCallbacksController

  before_action :maybe_redirect_back, only: [:passthru, :entra_id]

  # This method signs a user in after they authenticate with Microsoft SSO.
  def entra_id
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

  # TODO do this in routes!!
  def logout
    if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
      redirect_to logout_path, allow_other_host: true
      return
    else
      redirect_to end_session_path
      return
    end
  end

  # Let's tell users who navigate to /login what they should be doing:
  def courtesy_notice
    flash[:alert] = 'To log in using Microsoft Single Sign-On, click the "log in" button at the bottom of the page.'
    redirect_back(fallback_location: root_path)
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

  def logout_path
    @logout_path ||= OmniAuth::Strategies::EntraId::BASE_URL + 
      "/common/oauth2/v2.0/logout" + 
      "?post_logout_redirect_uri=" + 
      ScihistDigicoll::Env.lookup(:app_url_base) +
      end_session_path
  end


  def maybe_redirect_back
    unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
      flash[:alert] = "Sorry, you can't log in this way."
      redirect_back(fallback_location: root_path)
      return
    end
  end

end
