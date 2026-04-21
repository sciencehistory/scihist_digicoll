class OralHistoryConversationFeedbackController < ApplicationController
  before_action do
    # for now let anyone who can engage in conversations rate any conversation,
    # we don't record who issued which.
    authorize! :create, OralHistory::AiConversation
  end

  before_action :set_ai_conversation

  # displayed in modal
  def new

  end

  # response displayed in modal
  def create
    OralHistory::AiConversationFeedback.create!(
      feedback_params.merge(
        user: current_user,
        oral_history_ai_conversation: @ai_conversation,
      )
    )
  end

  private

  def set_ai_conversation
    # will raise NotFound leading to 404 if not found
    @ai_conversation = OralHistory::AiConversation.find_by_external_id!(params[:id])
  end

  def feedback_params
    params.require(:feedback).permit(:rating, :comment).tap do |hash|
      hash.delete(:comment) if hash[:comment].blank?
      hash.delete(:rating) if hash[:rating].to_i.zero?
    end
  end
end
