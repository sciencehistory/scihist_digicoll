class PasswordsController < Devise::PasswordsController
  def new
    return back if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    super
  end

  def edit
    return back if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    super
  end

  def update
    return back if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    super
  end

  def create
    return back if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    super
  end

  private
  def back
    flash[:alert] = "Passwords are managed in Microsoft SSO now."
    redirect_back(fallback_location: root_path)
  end
end