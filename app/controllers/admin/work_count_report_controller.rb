# Cumulative and per-month Work creation/publication counts.
class Admin::WorkCountReportController < AdminController
  def index
    @months = WorkCountReport.new.months_with_counts
  end
end
