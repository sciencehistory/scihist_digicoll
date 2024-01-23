require 'rails_helper'
RSpec.describe Admin::OralHistoryRequestsController, :logged_in_user, type: :controller do
  describe "Oral History Access Request List Controller", logged_in_user: :admin do
    let(:work) { create(:oral_history_work) }

    let!(:access_request_array) do
        (1..10).to_a.map do |i|
          delivery_status = ['automatic', 'approved', 'rejected', 'pending', nil][i % 5]
          OralHistoryRequest.create!(
            created_at: latest_date - 100000 * i,
            patron_name: "Patron #{i}",
            patron_email: "patron@institution_#{i}.com",
            patron_institution: "Institution #{i}",
            intended_use: "I will write #{i} books.",
            work: work,
            delivery_status: delivery_status
          )
      end
    end

    context "list on page" do
      render_views
      let(:latest_date) {Time.now}
      it "smoke test" do
        get :index
        expect(response.parsed_body.css('.request-list-delivery-status').count).to eq 10
      end
      it "can show only pending" do
        get :index, params: { "query"=> {"status"=>"pending"} }
        expect(response.parsed_body.css('.request-list-delivery-status').count).to eq 2
      end
      it "works with 'any' status" do
        get :index, params: { "query"=> {"status"=>"any"} }
        expect(response.parsed_body.css('.request-list-delivery-status').count).to eq 10
      end
    end

    context "csv report" do
      let(:latest_date) {Time.parse("2020-10-01")}
      it "allows you to download" do
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
  end
end
