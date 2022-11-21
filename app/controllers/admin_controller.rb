# A superclass for our admin/staff controllers with common logic
class AdminController < ApplicationController
  layout "admin"

  before_action :authorize_access

  def authorize_access
    unless can? :see_admin
      raise AccessGranted::AccessDenied.new("Only logged-in users can access admin screens")
    end
  end
end
