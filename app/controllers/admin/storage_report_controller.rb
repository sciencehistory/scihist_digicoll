# Lists recent asset derivative storage audits.
class Admin::StorageReportController < AdminController
  def index
    @report = Admin::AssetDerivativeStorageTypeReport.order(created_at: :desc).first
  end
end