# This controller provides methods used to authenticate a user using
# Microsoft Single Sign On / Entra / Azure.
# Links to more documentation are at config/initializers/devise.rb.
#
# Note that if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso) is not set to true, 
# this *entire* controller is turned off in config/routes.rb .
# (See devise_for :users in that file.)
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

  # Log a user out of the digital collections,
  # *then* log them out of Microsoft SSO.
  def sso_logout
    # There should not be a route to this method unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso).
    raise "This method should be unreachable." unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    sign_out current_user
    redirect_to sso_logout_path, allow_other_host: true
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

  def sso_logout_path
    @logout_path ||= OmniAuth::Strategies::EntraId::BASE_URL + 
      "/common/oauth2/v2.0/logout" + 
      "?post_logout_redirect_uri=" + 
      ScihistDigicoll::Env.lookup(:app_url_base) +
      root_path
  end

  def maybe_redirect_back
    unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
      flash[:alert] = "Sorry, you can't log in this way."
      redirect_back(fallback_location: root_path)
      return
    end
  end

end
