class CalculateFixityReportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    FixityReport.new.save_new
  end
end
