# STAFF FACING
# Public facing actions are in app/controllers/oral_history_access_requests_controller.rb
require 'csv'

class Admin::OralHistoryAccessRequestsController < AdminController
  def index
    @oral_history_access_requests = Admin::OralHistoryAccessRequest.
    where('created_at > ?', 3.months.ago).order(created_at: :desc).to_a
    @oral_history_numbers = oh_numbers(@oral_history_access_requests)
  end

  def report
    scope = Admin::OralHistoryAccessRequest

    start_date = params.dig('report', 'start_date')
    scope = scope.where('created_at > ?', start_date) if start_date.present?

    # add 24 hours to the end date, since
    # we think of this as an inclusive date range.
    end_date =  params.dig('report', 'end_date')
    scope = scope.where('created_at <= ?', (Time.parse(end_date) + 1.day)) if end_date.present?

    oral_history_numbers = oh_numbers(scope.all)

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
    ]

    scope.find_each do |request|
      data << [
        request.created_at,
        request.work.title,
        work_url(request.work),
        request.patron_name,
        oral_history_numbers[request.work.id],
        request.patron_email,
        request.patron_institution,
        request.intended_use,
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

  private
    # Fail gracefully if one of these works is missing an external ID for whatever reason.
    def oh_numbers(requests)
      # Note: see also oh_request.work.oral_history_content!.ohms_xml.accession
      result = {}
      requests.each do |oh_request|
        external_id = oh_request.work.external_id.
          find {|id| id.attributes["category"] == "interview"}
        result[oh_request.work.id] = external_id.attributes['value'] if external_id.present?
      end
      result
    end
end
