# A superclass for our admin/staff controllers with common logic
class AdminController < ApplicationController
  layout "admin"

  before_action :authorize_access

  # For now, admin controllers allow anyone who is logged in
  def authorize_access
    unless current_user.present?
      # raise the error from `access_granted` to be consistent.
      raise AccessGranted::AccessDenied.new("Only logged-in users can access admin screens")
    end
  end
end
