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
    let(:oh_request) { create(:oral_history_access_request) }

    it "rejects if no auth" do
      get :show, params: { id: oh_request.id }
      expect(response).to redirect_to(new_oral_history_session_path)
      expect(flash[:auto_link_message]).to eq "You must be authorized to access this page."
    end

    describe "unapproved request" do
      let(:oh_request) { create(:oral_history_access_request, delivery_status: "pending") }

      it "404s" do
        expect {
          get :show, params: { id: oh_request.id }
        }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end

