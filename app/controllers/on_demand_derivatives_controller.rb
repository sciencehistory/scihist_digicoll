# Use for our whole-work multi-image derivatives: PDF, zip. To create them on
# demand, via a background job, and provide JSON status messages for front-end
# to display progress and redirect to download, etc.p
class OnDemandDerivativesController < ApplicationController
  before_action :set_work, :validate_work

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

  def validate_work
    # Our on-demand derivatives all only include public children -- in part because we cache
    # these publically.
    #
    # if we don't have any public children, it's going to error out, better to abort it now
    # before even launching the bg job -- this doesn't yet catch all possible unsuitable
    # works that might raise later, but a good chunk of them.
    #
    # This makes the error-reporting clearer, making our operations easier.
    #
    # We do an efficient query not bringing back all records here.
    unless @work.members.where(published: true).exists?
      render json: { status: "error", error_info: {class: "ArgumentError", message: "Can't create derivative with no public members"}}, status: 403
    end
  end
end
