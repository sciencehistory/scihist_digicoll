class OralHistoryAiConversationController < ApplicationController
  # for now ALL require staff login, eventually we will gate so you can
  # only see your own questions
  before_action :authorize_access

  # For now, admin controllers allow anyone who is logged in
  def authorize_access
    unless can? :access_staff_functions
      # raise the error from `access_granted` to be consistent.
      raise AccessGranted::AccessDenied.new("Only logged-in staff can access this feature")
    end
  end

  # empty question form
  def new
    # counts for categories. TODO replace with DRY scopes, see #3253.

    valid_chunks_scope = OralHistoryContent.joins(:work).where(work: { published: true }).where.associated(:oral_history_chunks).distinct

    @immediate_ohms_only_count = Rails.cache.fetch("oh_access_limit_count/immediate_ohms_only", expires_in: 12.hours) do
      valid_chunks_scope.where.not( ohms_xml_text: [nil, ""]).count
    end

    @immediate_only_count = Rails.cache.fetch("oh_access_limit_count/immediate_only", expires_in: 12.hours) do
      valid_chunks_scope.where(available_by_request_mode: ["off", nil]).count
    end

    @immediate_or_automatic_count = Rails.cache.fetch("oh_access_limit_count/immediate_or_automatic", expires_in: 12.hours) do
      valid_chunks_scope.where(available_by_request_mode: ["off", nil, "automatic"]).count
    end

    @all_count = Rails.cache.fetch("oh_access_limit_count/all", expires_in: 12.hours) do
      valid_chunks_scope.count
    end
  end

  def create
    search_params = params.slice(:access_limit).to_unsafe_h

    conversation = OralHistoryAiConversationJob.launch(session_id: session.id, question: params.require(:q), search_params: search_params)

    redirect_to oral_history_ai_conversation_path(conversation.external_id)
  end

  # See your question and possibly answer if it's complete!
  def show
    @conversation = OralHistory::AiConversation.find_by_external_id(params.require(:id))
  end
end
