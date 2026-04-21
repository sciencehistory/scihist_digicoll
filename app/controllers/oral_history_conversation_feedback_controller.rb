class OralHistoryConversationFeedbackController < ApplicationController
  before_action do
    # for now let anyone who can engage in conversations rate any conversation,
    # we don't record who issued which.
    authorize! :create, OralHistory::AiConversation
  end

  # displayed in modal
  def new

  end

  # response displayed in modal
  def create

  end

end
