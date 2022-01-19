# Lists recent asset derivative storage audits.
class Admin::OrphanReportController < AdminController
  def index
    @report = Admin::OrphanReport.order(created_at: :desc).first
    @report_available =  @report&.end_time.present?
  end
end
