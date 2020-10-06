# Lists recent asset derivative storage audits.
class Admin::StorageReportController < AdminController
  def index
    @report = Admin::AssetDerivativeStorageTypeReport.order(created_at: :desc).limit(1).first
    render :storage_report
  end
end