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
    @immediate_ohms_only_count = OralHistory::CategoryWithChunksCount.new(category: :immediate_ohms_only).fetch_count
    @immediate_only_count = OralHistory::CategoryWithChunksCount.new(category: :immediate_only).fetch_count
    @immediate_or_automatic_count = OralHistory::CategoryWithChunksCount.new(category: :immediate_or_automatic).fetch_count
    @all_count = OralHistory::CategoryWithChunksCount.new(category: :all).fetch_count
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
