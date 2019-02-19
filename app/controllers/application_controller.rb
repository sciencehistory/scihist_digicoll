class ApplicationController < ActionController::Base
  # temporarily require auth for entire app
  before_action :authenticate_user!


  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You don't have permission to access requested page."
  end
end
