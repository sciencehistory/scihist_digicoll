# STAFF FACING
# Public facing actions are in app/controllers/oral_history_access_requests_controller.rb
require 'csv'

class Admin::OralHistoryAccessRequestsController < AdminController
  def index
    @oral_history_access_requests = Admin::OralHistoryAccessRequest.
    where('created_at > ?', 3.months.ago).to_a
  end

  def report
    scope = Admin::OralHistoryAccessRequest

    puts params
    # TODO: This doesn't quite slice the dates the way it should.
    # Investigate.
    start_date, end_date = nil
    if params['Start'].present?
      start_date = params['Start']['start_date']
      scope = scope.where('created_at > ?', start_date)
    end
    if params['End'].present?
      end_date = Time.parse(params['End']['end_date']) + 1.day
      # puts end_date
      # puts end_date.class
      #puts "GOOOAT"
      #puts(Time.parse(end_date))
      #puts(Time.parse(end_date) + 1.day)
      #puts(end_date + 1.day)
      scope = scope.where('created_at <= ?', end_date)
    end

    date_label = Date.today.to_s
    data = []
    data << [
      "Date",
      "Work",
      "Name of patron",
      "Email",
      "Institution",
      "Intended use",
    ]


    scope.find_each do |request|
      data << [
        request.created_at,
        request.work.title,
        request.patron_name,
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
end