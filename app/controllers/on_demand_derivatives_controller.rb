# Use for our whole-work multi-image derivatives: PDF, zip. To create them on
# demand, via a background job, and provide JSON status messages for front-end
# to display progress and redirect to download, etc.p
class OnDemandDerivativesController < ApplicationController
  before_action :set_work


  # Returns a JSON hash with status of on-demand derivative, including a URL
  # if it's available now at `file_url`.
  #
  # GET /works/:id/:derivative_type
  #
  # Will default to a URL with content-disposition attachment from S3, but for
  # inline client can request:
  #
  # GET /works/:id/:derivative_type?disposition=inline
  #
  # @returns JSON status info, including URL at `file_url` to download derivative if status success
  def on_demand_status
    record = OnDemandDerivativeCreator.new(@work, derivative_type: params[:derivative_type]).find_or_create_record

    json_result = record.as_json
    if record.success?
      json_result["file_url"] = record.file_url(disposition: params[:disposition])
    end

    render json: json_result
  end


  protected

  def set_work
    @work = Work.find_by_friendlier_id!(params[:id])
    authorize! :read, @work
  end
end
