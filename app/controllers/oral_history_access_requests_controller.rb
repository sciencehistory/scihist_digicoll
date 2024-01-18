# PUBLIC FACING
#
# Actions to make requests, and also to view your requsets.
#
# Staff-facing actions are in app/controllers/admin/oral_history_access_requests_controller.rb
class OralHistoryAccessRequestsController < ApplicationController
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

    @pending_requests = grouped_by["pending"] || []
    @approved_requests = ((grouped_by["approved"] || []) + (grouped_by["automatic"] || [])).sort_by(&:delivery_status_changed_at)
    @rejected_requests = (grouped_by["rejected"] || []).sort_by(&:delivery_status_changed_at)
  end

  # GET /oral_history_requests/:id
  def show
    @access_request = OralHistoryRequest.find(params[:id])

    # If they can't see it for any reason, just 404 as if it was not there.
    unless current_oral_history_requester == @access_request.oral_history_requester_email &&
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

  # GET /works/4j03d09fr7t/request_oral_history_access
  #
  # Form to fill out
  def new
    @work = load_work(params['work_friendlier_id'])
    @oral_history_access_request = OralHistoryRequest.new(work: @work)
  end

  # POST "/request_oral_history_access"
  #
  # Action to create request from form
  def create
    @work = load_work(params['oral_history_request'].delete('work_friendlier_id'))

    # note `create_or_find_by` is the version with fewer race conditions, to make
    # this record if it doesn't already exist.
    requester_email = (Admin::OralHistoryRequesterEmail.create_or_find_by!(email: patron_email_param) if patron_email_param.present?)

    # In new mode, check to see if request already exists,
    if ScihistDigicoll::Env.lookup("feature_new_oh_request_emails") && requester_email &&
        OralHistoryRequest.where(work: @work, oral_history_requester_email: requester_email).exists?

      want_request_dashboard_response(
        work: @work,
        requester_email: requester_email,
        emailed_notice: "You have already requested this Oral History. We've sent another email to #{patron_email_param} with a sign-in link.",
        immediate_notice: "You have already requested this Oral History"
      )

      return # abort further processing
    end

    @oral_history_access_request = OralHistoryRequest.new(
      oral_history_access_request_params.merge(
        work: @work,
        oral_history_requester_email: requester_email
      )
    )

    if @oral_history_access_request.save
      if @work.oral_history_content.available_by_request_automatic?
        @oral_history_access_request.update!(delivery_status: "automatic")

        if ScihistDigicoll::Env.lookup("feature_new_oh_request_emails")
          want_request_dashboard_response(
            work: @work,
            requester_email: requester_email,
            emailed_notice: "The files you have requested are immediately available. We've sent an email to #{patron_email_param} with a sign-in link.",
            immediate_notice: "The files you have requested are immediately available"
          )
        else
          OralHistoryDeliveryMailer.
            with(request: @oral_history_access_request).
            oral_history_delivery_email.
            deliver_later

          redirect_to work_path(@work.friendlier_id), notice: "Check your email! We are sending you links to the files you requested, to #{@oral_history_access_request.requester_email}."
        end
      else # manual review
        OralHistoryRequestNotificationMailer.
          with(request: @oral_history_access_request).
          notification_email.
          deliver_later

        redirect_to work_path(@work.friendlier_id), notice: "Thank you for your interest. Your request will be reviewed, usually within 3 business days, and we'll email you at #{@oral_history_access_request.requester_email}"
      end
    else
     render :new
    end

    # write entries to a cookie to pre-fill form next time; every time we write
    # it will bump the TTL expiration too, so they get another day until it expires.
    # Make sure to include the separate patron_eamil
    oral_history_request_form_entry_write(
      oral_history_access_request_params.merge(patron_email: patron_email_param).to_h
    )
  end

private

  # If they are logged in, we want to redirect them to their request dashboard -- if they are not,
  # we want to send them back to work page, and tell them we've sent them an email with
  # magic login link.
  #
  # Used both for requesting "automatic" delivery, AND for re-requesting an already requested file,
  # so we DRY extract to this method.
  #
  # @param work [Work] the OH work
  # @param requester_email [Admin::OralHistoryRequesterEmail] need this one too
  # @param emailed_notice [String] flash notice to let people know we'e emailed a link
  # @param immediate_notice [String] flash notice when they're already logged in and we're sending them right there
  def want_request_dashboard_response(work:, requester_email:, emailed_notice:, immediate_notice:)
    # new style, if they are already logged in they have immediate access, else an email
    if current_oral_history_requester.present? && current_oral_history_requester.email == requester_email.email
      redirect_to oral_history_requests_path, notice: immediate_notice
    else
      # Send em another email with login link
      OhSessionMailer.with(requester_email: requester_email).link_email.deliver_later
      redirect_to work_path(work.friendlier_id), notice: emailed_notice
    end
  end

  def oral_history_access_request_params
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
      @current_oral_history_requester = (Admin::OralHistoryRequesterEmail.find_by(id: session[OralHistorySessionsController::SESSION_KEY]) if session[OralHistorySessionsController::SESSION_KEY].present?)
    end
    @current_oral_history_requester
  end
  helper_method :current_oral_history_requester

end
