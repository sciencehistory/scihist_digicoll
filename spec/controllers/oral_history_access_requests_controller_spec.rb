require "rails_helper"

describe OralHistoryAccessRequestsController, type: :controller do
  describe "#index" do
    it "rejects if no auth" do
      get :index
      expect(response).to redirect_to(new_oral_history_session_path)
      expect(flash[:auto_link_message]).to eq "You must be authorized to access this page."
    end
  end

  describe "#show" do
    let(:oh_request) { create(:oral_history_access_request, delivery_status: "approved") }

    describe "no authorized user" do
      it "404s" do
        expect {
          get :show, params: { id: oh_request.id }
        }.to raise_error(ActionController::RoutingError)
      end
    end

    describe "wrong authorized user" do
      before do
        allow(session).to receive(:[]).and_call_original
        allow(session).to receive(:[]).with(OralHistorySessionsController::SESSION_KEY).
          and_return(Admin::OralHistoryRequesterEmail.create!(email: "example#{rand(999999)}@example.com").id)
      end

      it "404s" do
        expect {
          get :show, params: { id: oh_request.id }
        }.to raise_error(ActionController::RoutingError)
      end
    end

    describe "authorized user" do
      before do
        allow(session).to receive(:[]).and_call_original
        allow(session).to receive(:[]).with(OralHistorySessionsController::SESSION_KEY).and_return(oh_request.oral_history_requester_email.id)
      end

      describe "unapproved request" do
        let(:oh_request) { create(:oral_history_access_request, delivery_status: "pending") }

        it "404s" do
          expect {
            get :show, params: { id: oh_request.id }
          }.to raise_error(ActionController::RoutingError)
        end
      end

      describe "automatic request" do
        let(:oh_request) { create(:oral_history_access_request, delivery_status: "automatic") }

        it "shows" do
          get :show, params: { id: oh_request.id }
          expect(response).to have_http_status(:success)
        end
      end

      describe "approved request" do
        let(:oh_request) { create(:oral_history_access_request, delivery_status: "approved") }

        it "shows" do
          get :show, params: { id: oh_request.id }
          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end

