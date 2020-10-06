# Lists recent asset derivative storage audits.
class Admin::StorageReportController < AdminController
  def index
    @reports = Admin::AssetDerivativeStorageTypeReport.order(created_at: :desc).limit(1)
    render :storage_report
  end
end