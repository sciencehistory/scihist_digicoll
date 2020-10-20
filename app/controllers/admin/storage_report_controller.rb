# Lists recent asset derivative storage audits.
class Admin::StorageReportController < AdminController
  def index
    @report = Admin::AssetDerivativeStorageTypeReport.order(created_at: :desc).first
    unless @report.nil?
      @data = @report.data_for_report
      @incorrectly_published_sample_array = @data['incorrectly_published_sample'].split(",")
      @incorrect_storage_locations_sample_array = @data['incorrect_storage_locations_sample'].split(",")
    end
  end
end