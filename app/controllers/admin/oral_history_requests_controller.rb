# STAFF FACING
# Public facing actions are in app/controllers/oral_history_requests_controller.rb
require 'csv'

class Admin::OralHistoryRequestsController < AdminController
  def index
    status = params.dig(:query, :status)
    scope = OralHistoryRequest.includes(:oral_history_requester, :work)
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

  # POST /admin/oral_history_requests/:id/respond
  def respond
    @oral_history_request = OralHistoryRequest.find(params[:id])
    raise ArgumentError, "Unrecognized disposition: #{disposition}" unless ['approve', 'reject', 'dismiss'].include? disposition
    @oral_history_request.update!(delivery_status: delivery_status, notes_from_staff: custom_message)    
    maybe_enqueue_email
    redirect_to admin_oral_history_requests_path, notice: notice
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

  private

  def disposition
    @disposition ||= params[:disposition]
  end

  def delivery_status
    @delivery_status ||= {
      'approve' => 'approved',
      'reject'  => 'rejected',
      'dismiss' => 'dismissed'
    }[disposition]
  end

  def custom_message
    @custom_message ||= params.dig(:oral_history_request_approval, :notes_from_staff)
  end

  def notice
    @notice ||= case disposition
      when "approve"
        "Approve email was sent to #{@oral_history_request.requester_email} for '#{@oral_history_request.work.title}'"
      when  "reject"
        "Reject email was sent to #{@oral_history_request.requester_email} for '#{@oral_history_request.work.title}'"
      when "dismiss"
        "#{@oral_history_request.requester_email}'s request for '#{@oral_history_request.work.title}' has been dismissed. The request has been set aside and no email will be sent to the requester."      
    end
  end

  def maybe_enqueue_email
    mailer_method= {
      'approve' => :approved_with_session_link_email,
      'reject' =>  :rejected_with_session_link_email
    }[disposition]
    return if mailer_method.nil?
    
    OralHistoryDeliveryMailer.
      with(request: @oral_history_request, custom_message: notice).
      send(mailer_method).deliver_later
  end
end
