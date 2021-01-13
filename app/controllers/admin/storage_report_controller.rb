# Lists recent asset derivative storage audits.
class Admin::StorageReportController < AdminController
  def index
    @report = Admin::AssetDerivativeStorageTypeReport.order(created_at: :desc).first
    @data = @report.data_for_report unless @report.nil?
  end
end