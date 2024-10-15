class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def azure_activedirectory_v2
    response_params = request.env['omniauth.auth']['info']
    sanitized_email = User.sanitize_sql_like response_params['email']
    @user = User.where('email ILIKE ?', "%#{sanitized_email}%").first
    if @user&.persisted?
      flash[:notice] = 'Signed in successfully.'
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:danger] = "We couldn't find an account for you. Please contact an administrator."
      redirect_back(fallback_location: root_path)
    end
  end
end
