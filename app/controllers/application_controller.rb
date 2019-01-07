class ApplicationController < ActionController::Base
  # temporarily require auth for entire app
  before_action :authenticate_user!

end
