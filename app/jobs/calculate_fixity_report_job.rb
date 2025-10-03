class CalculateFixityReportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    FixityReport.new().recalculate_report
  end
end
