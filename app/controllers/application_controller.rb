class ApplicationController < ActionController::Base
  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You don't have permission to access requested page."
  end
end
