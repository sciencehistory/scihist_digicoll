# STAFF FACING

# Public facing actions are in app/controllers/oral_history_access_requests_controller.rb

class Admin::OralHistoryAccessRequestsController < AdminController
  before_action :set_oral_history_access_request, only: [:show, :edit, :update, :destroy]
  def index
    @oral_history_access_requests = Admin::OralHistoryAccessRequest.all.to_a
    #render 'admin/oral_history_access_requests/index'
  end
end