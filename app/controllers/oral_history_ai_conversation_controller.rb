class OralHistoryAiConversationController < ApplicationController
  # empty question form
  def new
    authorize! :create, OralHistory::AiConversation

    @immediate_ohms_only_count = OralHistory::CategoryWithChunksCount.new(category: :immediate_ohms_only).fetch_count
    @immediate_only_count = OralHistory::CategoryWithChunksCount.new(category: :immediate_only).fetch_count
    @immediate_or_automatic_count = OralHistory::CategoryWithChunksCount.new(category: :immediate_or_automatic).fetch_count
    @all_count = OralHistory::CategoryWithChunksCount.new(category: :all).fetch_count
  end

  def create
    authorize! :create, OralHistory::AiConversation

    search_params = params.slice(:access_limit).to_unsafe_h

    conversation = OralHistoryAiConversationJob.launch(session_id: session.id, question: params.require(:q), search_params: search_params)

    redirect_to oral_history_ai_conversation_path(conversation.external_id)
  end

  # See your question and possibly answer if it's complete!
  def show
    @conversation = OralHistory::AiConversation.find_by_external_id(params.require(:id))
    authorize! :read, @conversation
  end

  # hacky way to deliver partial HTML for our thing that should prob be
  # repalced by turbo-streams at some point
  def refresh
    conversation = OralHistory::AiConversation.find_by_external_id(params.require(:id))

    # only generate if there's been a change, and set last-modified header
    # We do manual etag so we can include same value in initial response too for comparison.
    if stale?(etag: conversation.cache_key_with_version)
      render OralHistory::AiConversationDisplayComponent.new(conversation), layout: false
    end
  end
end
