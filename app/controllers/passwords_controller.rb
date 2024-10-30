# To minimize confusion, let's make password manipulation unavailable if we're currently managing
# auth using Microsoft. These passwords are irrelevant and will just cause confusion, since the user likely
# has a totally different password in Entra.
class PasswordsController < Devise::PasswordsController
  before_action :maybe_redirect_back
  private
  def maybe_redirect_back
    return unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    flash[:alert] = "Passwords are managed in Microsoft SSO now."
    redirect_back(fallback_location: root_path)
    return
  end
end