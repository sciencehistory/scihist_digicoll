require "rails_helper"

describe OralHistoryRequestsController, type: :controller do
  describe "#index" do
    it "rejects if no auth" do
      get :index
      expect(response).to redirect_to(new_oral_history_session_path)
      expect(flash[:auto_link_message]).to eq "You must be authorized to access this page."
    end

    describe "null values in delivery_status_changed_at" do
      let!(:req_1) { create(:oral_history_request, delivery_status: "pending") }
      let(:requester) { req_1.oral_history_requester }

      let!(:req_2) { create(:oral_history_request, delivery_status: "approved",
          oral_history_requester:requester) }
      let!(:req_3) { create(:oral_history_request, delivery_status: "automatic",
          oral_history_requester:requester) }
      let!(:req_4) { create(:oral_history_request, delivery_status: "rejected",
          oral_history_requester:requester) }
      let!(:req_5) { create(:oral_history_request, delivery_status: "rejected",
          oral_history_requester:requester) }

      before do
        allow(controller).to receive(:current_oral_history_requester).and_return(requester)
        req_3.update(delivery_status_changed_at:nil)
        req_4.update(delivery_status_changed_at:nil)
      end

      it "does not throw an error" do
        get :index
        expect(Honeybadger.get_context[:oral_history_requester_email]).to eq req_1.oral_history_requester.email
      end
    end
  end


  describe "#show" do
    let(:oh_request) { create(:oral_history_request, delivery_status: "approved") }

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
          and_return(OralHistoryRequester.create!(email: "example#{rand(999999)}@example.com").id)
      end

      it "404s" do
        expect {
          get :show, params: { id: oh_request.id }
        }.to raise_error(ActionController::RoutingError)
      end
    end

    describe "authorized user" do
      before do
        allow(controller).to receive(:current_oral_history_requester).and_return(oh_request.oral_history_requester)
      end

      describe "unapproved request" do
        let(:oh_request) { create(:oral_history_request, delivery_status: "pending") }

        it "404s" do
          expect {
            get :show, params: { id: oh_request.id }
          }.to raise_error(ActionController::RoutingError)
        end
      end

      describe "automatic request" do
        let(:oh_request) { create(:oral_history_request, delivery_status: "automatic") }

        it "shows" do
          get :show, params: { id: oh_request.id }
          expect(response).to have_http_status(:success)
          expect(Honeybadger.get_context[:oral_history_requester_email]).to eq oh_request.oral_history_requester.email
        end
      end

      describe "approved request" do
        let(:oh_request) { create(:oral_history_request, delivery_status: "approved") }

        it "shows" do
          get :show, params: { id: oh_request.id }
          expect(response).to have_http_status(:success)
          expect(Honeybadger.get_context[:oral_history_requester_email]).to eq oh_request.oral_history_requester.email
        end
      end
    end
  end

  describe "#new" do
    let(:work) { create(:oral_history_work, :available_by_request)}

    it "displays form" do
      get :new, params: { work_friendlier_id: work.friendlier_id }
      expect(response).to have_http_status(:success)
    end

    describe "logged in, already has made request" do
      let(:patron_email) { "somebody@example.com" }
      let(:requester_email) { OralHistoryRequester.new(email: patron_email) }
      let!(:existing_request) {
        create(:oral_history_request,
          work: work,
          oral_history_requester: requester_email
        )
      }

      before do
        allow(controller).to receive(:current_oral_history_requester).and_return(requester_email)
      end

      it "redirects to dashboard" do
        get :new, params: { work_friendlier_id: work.friendlier_id }

        expect(response).to redirect_to(oral_history_requests_path)
        expect(flash[:success]).to match /You have already requested this Oral History/
        expect(Honeybadger.get_context[:oral_history_requester_email]).to eq requester_email.email
      end
    end
  end

  describe "#create" do
    let(:full_create_params) do
      {
        oral_history_request: {
          work_friendlier_id: work.friendlier_id,
          patron_name: "joe",
          patron_institution: "university of somewhere",
          intended_use: "I just like turtles",
        },
        patron_email: "joe@example.com"
      }
    end

    describe "email functionality" do
      let(:work) { create(:oral_history_work, :available_by_request)}
      describe "automatic delivery" do
        let(:work) { create(:oral_history_work, :available_by_request, available_by_request_mode: :automatic)}

        describe "already logged in" do
          let(:requester_email) { OralHistoryRequester.new(email: full_create_params[:patron_email]) }

          before do
            allow(controller).to receive(:current_oral_history_requester).and_return(requester_email)
          end

          it "redirects to dashboard" do
            expect {
              post :create, params: full_create_params
            }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
                expect(class_name).to eq "OralHistoryDeliveryMailer"
                expect(action).to eq "approved_with_session_link_email"
            }

            expect(response).to redirect_to(oral_history_requests_path)
            expect(flash[:success]).to match /The files you requested from '#{Regexp.escape work.title}' are immediately available./
            expect(Honeybadger.get_context[:oral_history_requester_email]).to eq requester_email.email

          end
        end

        describe "not already logged in" do
          it "emails a link" do
            expect {
              post :create, params: full_create_params
            }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
                expect(class_name).to eq "OralHistoryDeliveryMailer"
                expect(action).to eq "approved_with_session_link_email"
            }

            expect(Honeybadger.get_context[:oral_history_requester_email]).to eq full_create_params[:patron_email]
            expect(response).to redirect_to(work_path(work.friendlier_id))
            expect(flash[:success]).to match /The files you have requested are immediately available. We've sent an email to #{Regexp.escape full_create_params[:patron_email]} with a sign-in link/
          end
        end
      end

      describe "manual review" do
        # same as old style, we just let them know that they'll get an email.
        let(:work) { create(:oral_history_work, :available_by_request, available_by_request_mode: :manual_review)}

        it "emails admin, and lets user know" do
          expect {
            post :create, params: full_create_params
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
              expect(class_name).to eq "OralHistoryRequestNotificationMailer"
              expect(action).to eq "notification_email"
          }

          expect(response).to redirect_to(work_path(work.friendlier_id))
          expect(flash[:success]).to match /Your request will be reviewed/
          expect(Honeybadger.get_context[:oral_history_requester_email]).to eq full_create_params[:patron_email]
        end
      end


      describe "already had made request" do
        let(:requester_email) { OralHistoryRequester.new(email: full_create_params[:patron_email]) }
        let!(:existing_request) {
          create(:oral_history_request,
            work: work,
            oral_history_requester: requester_email
          )
        }

        describe "not already logged in" do
          it "sends a login link" do
            expect {
              post :create, params: full_create_params
            }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
              expect(class_name).to eq "OhSessionMailer"
              expect(action).to eq "link_email"
            }

            expect(response).to redirect_to(work_path(work.friendlier_id))
            expect(flash[:success]).to match /We've sent another email to #{Regexp.escape full_create_params[:patron_email]}/
            expect(Honeybadger.get_context[:oral_history_requester_email]).to eq full_create_params[:patron_email]
          end
        end
        describe "already logged in" do
          before do
            allow(controller).to receive(:current_oral_history_requester).and_return(requester_email)
          end

          it "redirects to dashboard" do
            expect {
              post :create, params: full_create_params
            }.not_to have_enqueued_job

            expect(response).to redirect_to(oral_history_requests_path)
            expect(flash[:success]).to match /You have already requested this Oral History/
            expect(Honeybadger.get_context[:oral_history_requester_email]).to eq full_create_params[:patron_email]
          end
        end
      end
    end

  end
end

