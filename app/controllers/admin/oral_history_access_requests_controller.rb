# STAFF FACING
# Public facing actions are in app/controllers/oral_history_access_requests_controller.rb
class Admin::OralHistoryAccessRequestsController < AdminController
  def index
    @oral_history_access_requests = Admin::OralHistoryAccessRequest.all.to_a
  end
end