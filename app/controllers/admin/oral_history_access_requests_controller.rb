# STAFF FACING
# Public facing actions are in app/controllers/oral_history_access_requests_controller.rb
require 'csv'

class Admin::OralHistoryAccessRequestsController < AdminController
  def index
    @oral_history_access_requests = Admin::OralHistoryAccessRequest.
      order(created_at: :desc).page(params[:page]).per(30)
  end

  # GET /admin/oral_history_access_requests/:id
  def show
    @oral_history_access_request = Admin::OralHistoryAccessRequest.find(params[:id])
  end

  # accept or reject
  # POST /admin/oral_history_access_requests/:id/respond
  def respond
    @oral_history_access_request = Admin::OralHistoryAccessRequest.find(params[:id])

    disposition = params[:disposition]
    custom_message = params.dig(:oral_history_access_request_approval, :message)

    if disposition == "approve"
      OralHistoryDeliveryMailer.
        with(request: @oral_history_access_request, custom_message: custom_message).
        oral_history_delivery_email.
        deliver_later

      @oral_history_access_request.update!(delivery_status: "approved")
    else
      # Let's just use the generic mailer with a text mail?
      ActionMailer::Base.mail(
        from: ScihistDigicoll::Env.lookup!(:oral_history_email_address),
        to: @oral_history_access_request.patron_email,
        bcc: ScihistDigicoll::Env.lookup!(:oral_history_email_address),
        subject: "Science History Institute: Your request",
        body: custom_message
      ).deliver_later

      @oral_history_access_request.update!(delivery_status: "rejected")
    end

    redirect_to admin_oral_history_access_requests_path,
      notice: "#{disposition.titlecase} email was sent to #{@oral_history_access_request.patron_email} for '#{@oral_history_access_request.work.title}'"
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
