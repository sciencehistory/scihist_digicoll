# Lists recent asset derivative storage audits.
class Admin::OrphanReportController < AdminController
  def index
    @report = Admin::OrphanReport.order(created_at: :desc).first
    @data = @report.data_for_report unless @report.nil?
  end
end