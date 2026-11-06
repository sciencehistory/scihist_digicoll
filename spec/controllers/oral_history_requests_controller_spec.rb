require "rails_helper"

describe OralHistoryRequestsController, type: :controller do
  describe "#index" do
    it "rejects if no auth" do
      get :index
      expect(response).to redirect_to(new_oral_history_session_path)
      expect(flash[:auto_link_message]).to eq "You must be authorized to access this page."
    end

    describe "null values in delivery_status_changed_at" do
      let(:patron) { create(:patron) }

      before do
        %w[pending approved rejected].each do |status|
          create(:oral_history_request, patron:, delivery_status: status)
        end
        # before_save sets delivery_status_changed_at, so blank it afterwards
        %w[automatic rejected].each do |status|
          create(:oral_history_request, patron:, delivery_status: status).update!(delivery_status_changed_at: nil)
        end
        allow(controller).to receive(:current_patron).and_return(patron)
      end

      it "does not throw an error" do
        get :index
        expect(Honeybadger.get_context[:patron_email]).to eq patron.email
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
        sign_in create(:patron)
      end

      it "404s" do
        expect {
          get :show, params: { id: oh_request.id }
        }.to raise_error(ActionController::RoutingError)
      end
    end

    describe "authorized user" do
      before do
        allow(controller).to receive(:current_patron).and_return(oh_request.patron)
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
          expect(Honeybadger.get_context[:patron_email]).to eq oh_request.patron.email
        end
      end

      describe "approved request" do
        let(:oh_request) { create(:oral_history_request, delivery_status: "approved") }

        it "shows" do
          get :show, params: { id: oh_request.id }
          expect(response).to have_http_status(:success)
          expect(Honeybadger.get_context[:patron_email]).to eq oh_request.patron.email
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
      let(:patron) { build(:patron) }
      let!(:existing_request) {
        create(:oral_history_request,
          work: work,
          patron: patron
        )
      }

      before do
        allow(controller).to receive(:current_patron).and_return(patron)
      end

      it "redirects to dashboard" do
        get :new, params: { work_friendlier_id: work.friendlier_id }

        expect(response).to redirect_to(oral_history_requests_path)
        expect(flash[:success]).to match /You have already requested this Oral History/
        expect(Honeybadger.get_context[:patron_email]).to eq patron.email
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
        let(:work) { create(:oral_history_work, :available_by_request, availability_mode: :automatic_request)}

        describe "already logged in" do
          let(:patron) { create(:patron, email: full_create_params[:patron_email]) }

          before do
            allow(controller).to receive(:current_patron).and_return(patron)
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
            expect(Honeybadger.get_context[:patron_email]).to eq patron.email

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

            expect(Honeybadger.get_context[:patron_email]).to eq full_create_params[:patron_email]
            expect(response).to redirect_to(work_path(work.friendlier_id))
            expect(flash[:success]).to match /The files you have requested are immediately available. We've sent an email to #{Regexp.escape full_create_params[:patron_email]} with a sign-in link/
          end
        end
      end

      describe "patron details" do
        let(:work) { create(:oral_history_work, :available_by_request, availability_mode: :reviewed_request)}

        it "stores name and institution on a new patron" do
          post :create, params: full_create_params

          patron = Patron.find_by!(email: full_create_params[:patron_email])
          expect(patron.name).to eq "joe"
          expect(patron.institution).to eq "university of somewhere"
          expect(patron).not_to be_confirmed
        end

        it "does not change an existing patron's details" do
          existing = create(:patron, email: full_create_params[:patron_email], name: "Original", institution: "Original U")

          post :create, params: full_create_params

          existing.reload
          expect(existing.name).to eq "Original"
          expect(existing.institution).to eq "Original U"
          expect(OralHistoryRequest.last.patron).to eq existing
        end

        it "shows error for missing name on a new patron" do
          params = full_create_params.deep_merge(oral_history_request: { patron_name: "" })
          expect {
            post :create, params: params
          }.not_to change { Patron.count }
          expect(response).to have_http_status(:success) # re-rendered form
          expect(assigns(:oral_history_request).errors[:patron_name]).to be_present
        end

        describe "signed in" do
          let(:patron) { create(:patron, name: "Signed In") }
          before { sign_in patron }

          it "uses signed-in patron, ignoring submitted details" do
            post :create, params: full_create_params.except(:patron_email)

            request = OralHistoryRequest.last
            expect(request.patron).to eq patron
            expect(patron.reload.name).to eq "Signed In"
          end
        end
      end

      describe "manual review" do
        # same as old style, we just let them know that they'll get an email.
        let(:work) { create(:oral_history_work, :available_by_request, availability_mode: :reviewed_request)}

        it "emails admin, and lets user know" do
          expect {
            post :create, params: full_create_params
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
              expect(class_name).to eq "OralHistoryRequestNotificationMailer"
              expect(action).to eq "notification_email"
          }

          expect(response).to redirect_to(work_path(work.friendlier_id))
          expect(flash[:success]).to match /Your request will be reviewed/
          expect(Honeybadger.get_context[:patron_email]).to eq full_create_params[:patron_email]
        end
      end


      describe "already had made request" do
        let(:patron) { build(:patron, email: full_create_params[:patron_email]) }
        let!(:existing_request) {
          create(:oral_history_request,
            work: work,
            patron: patron
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
            expect(Honeybadger.get_context[:patron_email]).to eq full_create_params[:patron_email]
          end
        end
        describe "already logged in" do
          before do
            allow(controller).to receive(:current_patron).and_return(patron)
          end

          it "redirects to dashboard" do
            expect {
              post :create, params: full_create_params
            }.not_to have_enqueued_job

            expect(response).to redirect_to(oral_history_requests_path)
            expect(flash[:success]).to match /You have already requested this Oral History/
            expect(Honeybadger.get_context[:patron_email]).to eq full_create_params[:patron_email]
          end
        end
      end
    end

  end
end

