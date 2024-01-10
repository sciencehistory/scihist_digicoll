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

  describe "#create" do
    let(:full_create_params) do
      {
        admin_oral_history_access_request: {
          work_friendlier_id: work.friendlier_id,
          patron_name: "joe",
          patron_institution: "university of somewhere",
          intended_use: "I just like turtles",
        },
        patron_email: "joe@example.com"
      }
    end

    describe "with old email functionality" do
      describe "automatic delivery" do
        let(:work) { create(:oral_history_work, :available_by_request, available_by_request_mode: :automatic)}

        it "emails files" do
          expect {
            post :create, params: full_create_params
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
              expect(class_name).to eq "OralHistoryDeliveryMailer"
              expect(action).to eq "oral_history_delivery_email"
          }

          expect(response).to redirect_to(work_path(work.friendlier_id))
          expect(flash[:notice]).to match /We are sending you links to the files you requested/
        end
      end

      describe "manual review" do
        let(:work) { create(:oral_history_work, :available_by_request, available_by_request_mode: :manual_review)}

        it "emails admin, and lets user know" do
          expect {
            post :create, params: full_create_params
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
              expect(class_name).to eq "OralHistoryRequestNotificationMailer"
              expect(action).to eq "notification_email"
          }

          expect(response).to redirect_to(work_path(work.friendlier_id))
          expect(flash[:notice]).to match /Your request will be reviewed/
        end
      end
    end
  end
end

