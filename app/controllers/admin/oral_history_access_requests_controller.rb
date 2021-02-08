# STAFF FACING
# Public facing actions are in app/controllers/oral_history_access_requests_controller.rb
require 'csv'

class Admin::OralHistoryAccessRequestsController < AdminController
  def index
    @oral_history_access_requests = Admin::OralHistoryAccessRequest.
    where('created_at > ?', 3.months.ago).order(created_at: :desc).to_a
  end

  def report
    scope = Admin::OralHistoryAccessRequest

    start_date = params.dig('report', 'start_date')
    scope = scope.where('created_at > ?', start_date) if start_date.present?

    # add 24 hours to the end date, since
    # we think of this as an inclusive date range.
    end_date =  params.dig('report', 'end_date')
    scope = scope.where('created_at <= ?', (Time.parse(end_date) + 1.day)) if end_date.present?
    date_label = Date.today.to_s
    data = []
    data << [
      "Date",
      "Work",
      "Work URL",
      "Oral History ID",
      "Name of patron",
      "Email",
      "Institution",
      "Intended use",
      "Delivery status"
    ]

    scope.find_each do |request|
      data << [
        request.created_at,
        request.work.title,
        work_url(request.work),
        request.oral_history_number,
        request.patron_name,
        request.patron_email,
        request.patron_institution,
        request.intended_use,
        request.delivery_status
      ]
    end

    begin
      output_csv_file = Tempfile.new
      CSV.open(output_csv_file, "wb") do |csv|
        data.each do |row|
          csv << row
        end
      end
      send_file output_csv_file.path, filename: "oral_history_access_requests-#{date_label}.csv"
    ensure
      output_csv_file.close
    end
  end
end
