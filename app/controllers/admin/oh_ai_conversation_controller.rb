class Admin::OhAiConversationController < AdminController
  # list existing questions
  def index
    relation = OralHistory::AiConversation.order(created_at: :desc).page(params[:page])

    if params[:q].present?
      relation = relation.where("question ILIKE ?", "%#{params[:q]}%")
    end

    @ai_conversations = relation.all
  end
end
