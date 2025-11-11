# PUBLIC FACING
#
# Actions to make requests, and also to view your requsets.
#
# Staff-facing actions are in app/controllers/admin/oral_history_requests_controller.rb
class OralHistoryRequestsController < ApplicationController

  before_action :add_requester_email_to_honeybadger_context

  # message is publicly visible please
  class AccessDenied < StandardError
    def initialize(msg = "You must be authorized to access this page.")
      super
    end
  end

  include OralHistoryRequestFormMemoryHelper

  rescue_from AccessDenied do |exception|
    redirect_to new_oral_history_session_path, flash: { auto_link_message: exception.message }
  end

  # GET /oral_history_requests
  #
  # List of this user's oral history requests. Protected from login.
  def index
    unless current_oral_history_requester.present?
      raise AccessDenied.new
    end


    all_requests = current_oral_history_requester.oral_history_requests.
      includes(:work => [:leaf_representative, { :oral_history_content => :interviewee_biographies } ]).
      order(created_at: :asc).
      strict_loading

    grouped_by = all_requests.group_by(&:delivery_status)
    null_ts = Time.utc(1,1,1,1,1,1)

    @pending_requests = grouped_by["pending"] || []

    @approved_requests = (
      (grouped_by["approved"]  || []) + (grouped_by["automatic"] || [])
    ).sort_by do |req|
      req.delivery_status_changed_at || null_ts
    end

    @rejected_requests = (grouped_by["rejected"] || []).sort_by do |req|
      req.delivery_status_changed_at || null_ts
    end
  end

  # GET /oral_history_requests/:id
  def show
    @access_request = OralHistoryRequest.find(params[:id])

    # If they can't see it for any reason, just 404 as if it was not there.
    unless current_oral_history_requester == @access_request.oral_history_requester &&
          (@access_request.delivery_status_approved? || @access_request.delivery_status_automatic?)
      raise ActionController::RoutingError.new("Not found.")
    end

    # Calculate assets avail by request, broken up by type
    all_by_request_assets = @access_request.work.members.
      where(published: false).
      includes(:leaf_representative).order(:position).strict_loading.
      to_a.find_all do |member|
        member.kind_of?(Asset) &&  member.oh_available_by_request?
      end

    @transcript_assets = all_by_request_assets.find_all { |a| a.role == "transcript" }
    @audio_assets = all_by_request_assets.find_all { |a| a.content_type.start_with?("audio/") }
    @other_assets = all_by_request_assets.find_all { |a| !@transcript_assets.include?(a) && !@audio_assets.include?(a) }
  end

  # GET /works/4j03d09fr7t/request_oral_history
  #
  # Form to fill out
  def new
    @work = load_work(params['work_friendlier_id'])

    # In new mode, check to see if the are logged in, and request already exists,
    # just send them to their requests!
    if current_oral_history_requester &&
          OralHistoryRequest.where(work: @work, oral_history_requester: current_oral_history_requester).exists?

        return_status(
          oral_history_requests_path,
          "You have already requested this Oral History: #{@work.title}",
          add_view_requests_link: true
        )

        return # abort further processing
    end

    @oral_history_request = OralHistoryRequest.new(work: @work)
  end

  before_action :setup_create_request, only: :create

  # POST "/request_oral_history"
  #
  # Action to create request from form
  def create
    # write entries to a cookie to pre-fill form next time; every time we write
    # it will bump the TTL expiration too, so they get another day until it expires.
    # Make sure to include the separate patron_eamil
    oral_history_request_form_entry_write(
      oral_history_request_params.merge(patron_email: patron_email_param).to_h
    )

    saved_valid = @oral_history_request.save

    unless saved_valid
      render :new
      return
    end

    if @work.oral_history_content.available_by_request_automatic?
      @oral_history_request.update!(delivery_status: "automatic")

      # If they are already logged in, they can just be directed to see this
      # automatically-approved request. Either way they should get an email,
      # per specs from OH team.
      OralHistoryDeliveryMailer.with(request: @oral_history_request).approved_with_session_link_email.deliver_later

      if current_oral_history_requester.present? && current_oral_history_requester.email == @oral_history_request.requester_email
        return_status(oral_history_requests_path,
          "The files you requested from '#{@work.title}' are immediately available and can be viewed now",
          add_view_requests_link: true
        )
      else
        return_status(
          work_path(@work.friendlier_id),
          "The files you have requested are immediately available. We've sent an email to #{patron_email_param} with a sign-in link."
        )
      end
    else # manual review
      OralHistoryRequestNotificationMailer.
        with(request: @oral_history_request).
        notification_email.
        deliver_later

      return_status(
        work_path(@work.friendlier_id),
        "Thank you for your interest. Your request will be reviewed, usually within 3 business days, and we'll email you at #{@oral_history_request.requester_email}"
      )
    end
  end

private

  # display a message in a redirect with flash, or an inline HTML fragment for JS placement in modal,
  # depending on request type
  #
  # @param return_dest argument to redirect_to if we are redirecting
  # @param message [String] message for flash message and/or modal
  # @param alert_type [String] flash type and `alert_$$` class for alert
  # @param add_view_requests_link [Boolean] if true, then in modal we'll add a link to View your requests.
  def return_status(redirect_dest, message, alert_type: "success", add_view_requests_link: false)
    if request.xhr?
      if add_view_requests_link
        message = <<~EOS.html_safe
          <p>#{ERB::Util.html_escape message}</p>
          <p>
            <i class="fa fa-external-link" aria-hidden="true"></i>
            <a href="#{oral_history_requests_path}" target="_blank">View your requests here</a>
          </p>
        EOS
      end

      render partial: "alert", layout: false, locals: { alert_type: "success", message: message }
    else
      redirect_to redirect_dest, flash: { alert_type => message }
    end
  end

  # load @work, and create a new @oral_history_request
  #
  # Depending on config, we may abort if request already exists. As a before_action,
  # redirecting or rendering will abort further processing.
  def setup_create_request
    @work = load_work(params['oral_history_request'].delete('work_friendlier_id'))

    # note `create_or_find_by` is the version with fewer race conditions, to make
    # this record if it doesn't already exist.
    requester_email = (OralHistoryRequester.create_or_find_by!(email: patron_email_param) if patron_email_param.present?)


    # Check to see if request already exists,
    if requester_email && OralHistoryRequest.where(work: @work, oral_history_requester: requester_email).exists?
      # If they are already authenticated, we can just direct them there,
      # otherwise we send them a sign-in link
      if current_oral_history_requester.present? && current_oral_history_requester.email == requester_email.email
        return_status(
          oral_history_requests_path,
          "You have already requested this Oral History: #{@work.title}",
          add_view_requests_link: true
        )
      else
        OhSessionMailer.with(requester_email: requester_email).link_email.deliver_later
        return_status(
          work_path(@work.friendlier_id),
          "You have already requested this Oral History. We've sent another email to #{patron_email_param} with a sign-in link, which you can use to view your requests."
        )
      end

      return false # abort further processing
    end


    @oral_history_request = OralHistoryRequest.new(
      oral_history_request_params.merge(
        work: @work,
        oral_history_requester: requester_email
      )
    )

    return true
  end


  def oral_history_request_params
    params.require(:oral_history_request).permit(
      :work_friendlier_id, :patron_name,
      :patron_institution, :intended_use)
  end

  def patron_email_param
    params[:patron_email] or raise ActionController::ParameterMissing.new(:patron_email)
  end

  def load_work(friendlier_id)
    work = Work.find_by_friendlier_id!(friendlier_id)
    #   # No sense showing this form for a work that is either freely available
    #   # or locked down. (This should never happen, but just in case.)
    unless WorkFileListShowComponent.new(work).available_by_request_assets.present?
      Rails.logger.warn("/works/#{work.friendlier_id}/request_oral_history_access: Can't request oral history access, no eligible files.")

      # ActionController::RoutingError will just tell Rails to render standard 404.
      raise ActionController::RoutingError.new('Not Found')
    end
    work
  end

  def current_oral_history_requester
    unless defined?(@current_oral_history_requester)
      @current_oral_history_requester = OralHistorySessionsController.fetch_oral_history_current_requester(request: request, reset_expiration_window: true)
    end
    @current_oral_history_requester
  end
  helper_method :current_oral_history_requester


  def add_requester_email_to_honeybadger_context
    # Get this info either from the session (via current_oral_history_requester) or from the :patron_email parameter.
    # Note: this method has the side effect of resetting the expiration window of the OH request.
    email = current_oral_history_requester&.email || params[:patron_email]
    Honeybadger.context({ oral_history_requester_email: email  })
  end

end
