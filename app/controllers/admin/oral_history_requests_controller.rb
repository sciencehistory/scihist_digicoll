# STAFF FACING
# Public facing actions are in app/controllers/oral_history_requests_controller.rb
require 'csv'

class Admin::OralHistoryRequestsController < AdminController
  def index
    status = params.dig(:query, :status)
    scope = OralHistoryRequest
    unless status == "any" || status.blank?
      scope = scope.where(delivery_status: status)
    end
    @oral_history_requests = scope.order(created_at: :desc).page(params[:page]).per(300)
  end

  def status_filter_options
    status_filter_options ||= begin
      selected_status = params.dig(:query, :status) || ""
      statuses = OralHistoryRequest.delivery_statuses.keys
      capital_statuses = statuses.map { |s|  ActiveSupport::Inflector.titleize(s) }
      options =  ([['Any', 'any']] + capital_statuses.zip(statuses)).to_h
      helpers.options_for_select(options, selected_status)
    end
  end
  helper_method :status_filter_options

  # GET /admin/oral_history_requests/:id
  def show
    @oral_history_request = OralHistoryRequest.find(params[:id])
  end

  # accept or reject
  # POST /admin/oral_history_requests/:id/respond
  def respond
    @oral_history_request = OralHistoryRequest.find(params[:id])

    disposition = params[:disposition]
    custom_message = params.dig(:oral_history_request_approval, :notes_from_staff)

    if disposition == "approve"
      @oral_history_request.update!(delivery_status: "approved", notes_from_staff: custom_message)

      mailer_action = if ScihistDigicoll::Env.lookup("feature_new_oh_request_emails")
        :approved_with_session_link_email
      else
        :oral_history_delivery_email
      end

      OralHistoryDeliveryMailer.
        with(request: @oral_history_request, custom_message: custom_message).
        public_send(mailer_action).
        deliver_later
    else
      @oral_history_request.update!(delivery_status: "rejected", notes_from_staff: custom_message)

      if ScihistDigicoll::Env.lookup("feature_new_oh_request_emails")
        OralHistoryDeliveryMailer.
          with(request: @oral_history_request, custom_message: custom_message).
          rejected_with_session_link_email.
          deliver_later
      else
        # Let's just use the generic mailer with a text mail?
        ActionMailer::Base.mail(
          from: ScihistDigicoll::Env.lookup!(:oral_history_email_address),
          to: @oral_history_request.requester_email,
          bcc: ScihistDigicoll::Env.lookup!(:oral_history_email_address),
          subject: "Science History Institute: Your request",
          body: custom_message
        ).deliver_later
      end
    end

    redirect_to admin_oral_history_requests_path,
      notice: "#{disposition.titlecase} email was sent to #{@oral_history_request.requester_email} for '#{@oral_history_request.work.title}'"
  end

  def report
    scope = OralHistoryRequest

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
        request.requester_email,
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
