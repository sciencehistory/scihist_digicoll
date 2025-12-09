require "rails_helper"

describe OralHistoryAiConversationController, :logged_in_user, type: :controller do
  describe "#new" do
    it "can render page" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "#create" do
    let(:question) { "How do you do it?" }
    it "creates state object, and redirects to show" do
      expect {
        get :create, params: { q: question }
      }.to change(OralHistory::AiConversation, :count).by(1)

      last_conversation = OralHistory::AiConversation.last

      expect(last_conversation.question).to eq question

      expect(response).to redirect_to(oral_history_ai_conversation_path(last_conversation.external_id))

      expect(OralHistoryAiConversationJob).to have_been_enqueued
    end

    describe "with blank q" do
      let(:question) { "    " }
      it "errors" do
        expect {
          get :create, params: { q: question }
        }.to raise_error(ActionController::ParameterMissing).and change(OralHistory::AiConversation, :count).by(0)
      end
    end
  end

  describe "#show" do
    render_views

    describe "in progress" do
      let(:conversation) { create(:ai_conversation, status: :in_process) }

      it "can show" do
        get :show, params: { id: conversation.external_id }

        expect(response).to have_http_status(:success)
        expect(response.body).to include "Computing..."
        # cheesy way to do it for now
        expect(response.body).to include '<meta http-equiv="refresh"'
      end
    end

    describe "error" do
      let(:conversation) { create(:ai_conversation, status: :error) }

      it "can show" do
        get :show, params: { id: conversation.external_id }

        expect(response).to have_http_status(:success)
        expect(response.body).to include "Sorry, an error happened!  Error object #{conversation.external_id}."
      end
    end

    describe "complete" do
      let(:conversation) { create(:ai_conversation, status: :success, answer_json: {}) }

      it "can show" do
        get :show, params: { id: conversation.external_id }

        expect(response).to have_http_status(:success)

        expect(response.body).not_to include '<meta http-equiv="refresh"'
      end
    end
  end
end
