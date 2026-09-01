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

    # default :logged_in_user is a staff_viewer, who has :access_staff_functions and so
    # can always opt in to searching restricted OH's, regardless of feature flag.
    describe "with include restricted, as staff user" do
      it "has no access restrictions" do
        expect {
          get :create, params: { q: question, include_restricted: "1" }
        }.to change(OralHistory::AiConversation, :count).by(1)

        last_conversation = OralHistory::AiConversation.last
        expect(last_conversation.search_params['access_limit']).to be_blank
      end
    end

    describe "without include restricted" do
      it "has access restrictions only avoiding needs_approval" do
        expect {
          get :create, params: { q: question, include_restricted: "0" }
        }.to change(OralHistory::AiConversation, :count).by(1)

        last_conversation = OralHistory::AiConversation.last
        expect(last_conversation.search_params['access_limit']).to eq "immediate_or_automatic"
      end
    end

    # A non-staff user (no :access_staff_functions) can only search restricted OH's
    # when the :ai_searchable_restricted_oh feature flag is on.
    describe "as non-staff user" do
      before do
        sign_in FactoryBot.create(:basic_internal_user, email: "basic-internal@sciencehistory.org")
      end

      describe "with :ai_searchable_restricted_oh flag off (default)" do
        it "ignores include_restricted and forces access restrictions anyway" do
          expect {
            get :create, params: { q: question, include_restricted: "1" }
          }.to change(OralHistory::AiConversation, :count).by(1)

          expect(OralHistory::AiConversation.last.search_params['access_limit']).to eq "immediate_or_automatic"
        end
      end

      describe "with :ai_searchable_restricted_oh flag on" do
        before do
          allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
          allow(ScihistDigicoll::Env).to receive(:lookup).with(:ai_searchable_restricted_oh).and_return(true)
        end

        it "allows unrestricted search with include_restricted param" do
          expect {
            get :create, params: { q: question, include_restricted: "1" }
          }.to change(OralHistory::AiConversation, :count).by(1)

          expect(OralHistory::AiConversation.last.search_params['access_limit']).to be_blank
        end

        it "restricts without include_restricted param" do
          get :create, params: { q: question, include_restricted: "0" }
          expect(OralHistory::AiConversation.last.search_params['access_limit']).to eq "immediate_or_automatic"
        end
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
        expect(response.body).to include "Identifying"
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
