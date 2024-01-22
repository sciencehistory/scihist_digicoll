require 'rails_helper'
RSpec.describe Admin::OralHistoryRequestsController, logged_in_user: :admin, type: :controller do

  describe "#index" do
    it "renders the list of requests even if an OH has no interview number" do
      get :index
      expect(response.code).to eq "200"
    end
  end

  describe "#report" do
    let(:work) { create(:oral_history_work) }

    let(:latest_date) {Time.parse("2020-10-01")}

    let!(:access_request_array) do
        (1..10).to_a.map do |i|
          OralHistoryRequest.create!(
            created_at: latest_date - 100000 * i,
            patron_name: "Patron #{i}",
            oral_history_requester: OralHistoryRequester.create_or_find_by(email: "patron@institution_#{i}.com"),
            patron_institution: "Institution #{i}",
            intended_use: "I will write #{i} books.",
            work: work
          )
      end
    end

    it "allows you to download the report" do
      post :report
      expect(response.code).to eq "200"
      expect(response.headers["Content-Disposition"]).to match(/attachment; filename=.*oral_history_access_requests.*csv/)
      expect(response.media_type).to eq "text/csv"
      csv_response = CSV.parse(response.body)
      expect(csv_response.count).to eq 11
      expect(csv_response[0]).to contain_exactly('Date','Work','Work URL', 'Oral History ID', 'Name of patron','Email','Institution','Intended use', 'Delivery status')
      expect(csv_response[8][1]).to match  /Oral history interview with William John Bailey/
      expect(csv_response[8][3]).to match  /0012/
      expect(csv_response[8][4]).to match  /Patron 8/
      expect(csv_response[8][5]).to match  /patron@institution_8.com/
      expect(csv_response[8][6]).to match  /Institution 8/
      expect(csv_response[8][7]).to match  /I will write 8 books/
      expect(csv_response[8][8]).to eq     "pending"
    end

    it "correctly interprets start and end date params" do
      params = {"report"=>{"start_date"=>"2020-09-21", "end_date"=>"2020-09-26"}}
      post :report, params: params
      expect(response.media_type).to eq "text/csv"
      csv_response = CSV.parse(response.body)
      expect(csv_response.count).to eq 6
      expect(csv_response[5][6]).to match  /Institution 8/
    end
  end

  describe "respond", queue_adapter: :inline do
    let(:message) { "custom message from staff" }
    let(:oral_history_access_request) { create(:oral_history_request, delivery_status: "pending") }

    it "can approve" do
      post :respond, params: {
        id: oral_history_access_request.id,
        disposition: "approve",
        oral_history_access_request_approval: { notes_from_staff: message }
      }

      expect(flash[:notice]).to match /Approve email was sent to #{Regexp.escape oral_history_access_request.requester_email}/
      expect(response).to redirect_to(admin_oral_history_requests_path)

      oral_history_access_request.reload
      expect(oral_history_access_request.delivery_status).to eq "approved"

      last_email = ActionMailer::Base.deliveries.last
      expect(last_email.subject).to eq "Science History Institute: files from #{oral_history_access_request.work.title}"
      expect(last_email.from).to eq [ScihistDigicoll::Env.lookup(:oral_history_email_address)]
      expect(last_email.body).to match /Here are your requested files/
      expect(last_email.body).to include(message)
    end

    it "can reject" do
      post :respond, params: {
        id: oral_history_access_request.id,
        disposition: "reject",
        oral_history_access_request_approval: { notes_from_staff: message }
      }


      expect(flash[:notice]).to match /Reject email was sent to #{Regexp.escape oral_history_access_request.requester_email}/
      expect(response).to redirect_to(admin_oral_history_requests_path)

      oral_history_access_request.reload
      expect(oral_history_access_request.delivery_status).to eq "rejected"

      last_email = ActionMailer::Base.deliveries.last
      expect(last_email.subject).to eq "Science History Institute: Your request"
      expect(last_email.from).to eq [ScihistDigicoll::Env.lookup(:oral_history_email_address)]
      expect(last_email.body).to include(message)
    end

    describe "with new request dashboard funtionality" do
      before do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with("feature_new_oh_request_emails").and_return(true)
      end

      it "can approve" do
        post :respond, params: {
          id: oral_history_access_request.id,
          disposition: "approve",
          oral_history_access_request_approval: { notes_from_staff: message }
        }

        expect(flash[:notice]).to match /Approve email was sent to #{Regexp.escape oral_history_access_request.requester_email}/
        expect(response).to redirect_to(admin_oral_history_requests_path)

        oral_history_access_request.reload
        expect(oral_history_access_request.delivery_status).to eq "approved"

        last_email = ActionMailer::Base.deliveries.last
        expect(last_email.subject).to eq "Science History Institute: Access files for #{oral_history_access_request.work.title}"
        expect(last_email.from).to eq [ScihistDigicoll::Env.lookup(:oral_history_email_address)]
        expect(last_email.body).to match /You can access your Oral History requests using this special login link/
      end

      it "can reject" do
        post :respond, params: {
          id: oral_history_access_request.id,
          disposition: "reject",
          oral_history_access_request_approval: { notes_from_staff: message }
        }

        expect(flash[:notice]).to match /Reject email was sent to #{Regexp.escape oral_history_access_request.requester_email}/
        expect(response).to redirect_to(admin_oral_history_requests_path)

        oral_history_access_request.reload
        expect(oral_history_access_request.delivery_status).to eq "rejected"

        last_email = ActionMailer::Base.deliveries.last
        expect(last_email.subject).to eq "Science History Institute: Your request for #{oral_history_access_request.work.title}"
        expect(last_email.from).to eq [ScihistDigicoll::Env.lookup(:oral_history_email_address)]
        expect(last_email.body).to match /Unfortunately we could <b>not<\/b> approve your request/
        expect(last_email.body).to include(message)
      end
    end
  end
end
