class CalculateFixityReportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    FixityReport.new.write_new_report_to_cache
  end
end
