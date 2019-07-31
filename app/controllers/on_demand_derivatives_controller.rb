# Use for our whole-work multi-image derivatives: PDF, zip. To create them on
# demand, via a background job, and provide JSON status messages for front-end
# to display progress and redirect to download, etc.p
class OnDemandDerivativesController < ApplicationController
  before_action :set_work


  # Returns a JSON hash with status of on-demand derivative, including a URL
  # if it's available now
  #
  # GET /works/:id/:derivative_type
  #
  # returns JSON status info, including URL to download derivative if status success
  def on_demand_status
    record = OnDemandDerivativeCreator.new(@work, derivative_type: params[:derivative_type]).find_or_create_record

    render json: record.as_json(methods: (record.success? ? "file_url" : nil))
  end


  protected

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
    authorize! :read, @work
  end
end
