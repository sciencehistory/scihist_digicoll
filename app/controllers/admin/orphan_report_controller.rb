# Lists recent asset derivative storage audits.
class Admin::OrphanReportController < AdminController
  def index
    @report = Admin::OrphanReport.order(created_at: :desc).first
    @report_available =  @report&.end_time.present?
  end

  private

  # Strip out any prefix part from shrine storage to get just the id
  helper_method def display_s3_url(url, storage:)
    path = URI.parse(url).path.delete_prefix("/")
    if storage.prefix.present?
      path = path.delete_prefix(storage.prefix).delete_prefix("/")
    end
    path
  end
end
