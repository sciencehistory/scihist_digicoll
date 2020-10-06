# Lists recent asset derivative storage audits.
class Admin::StorageReportController < AdminController
  def index
    @reports = Admin::AssetDerivativeStorageTypeReport.order(created_at: :desc)
    render :storage_report
  end
end