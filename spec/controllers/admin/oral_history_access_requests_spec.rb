require 'rails_helper'
RSpec.describe Admin::OralHistoryAccessRequestsController, :logged_in_user, type: :controller do
  describe "Oral History Access Request List Controller", logged_in_user: :admin do

    let(:work) { create(:oral_history_work) }

    let(:latest_date) {Time.parse("2020-10-01")}

    let!(:access_request_array) do
        (1..10).to_a.map do |i|
          Admin::OralHistoryAccessRequest.create!(
            created_at: latest_date - 100000 * i,
            patron_name: "Patron #{i}",
            patron_email: "patron@institution_#{i}.com",
            patron_institution: "Institution #{i}",
            intended_use: "I will write #{i} books.",
            work: work
          )
      end
    end

    it "allows you to download the report, and correctly interprets start and end date params" do
      puts access_request_array.map { |ar| ar.created_at.to_s }.to_a
      params = {
        "Start"=>{"start_date"=>"2020-09-21"},
        "End"=>{"end_date"=>"2020-09-26"},
        "commit"=>"Download report",
        "controller"=>"admin/oral_history_access_requests",
        "action"=>"report"
      }
      post :report, params: params
      expect(response.code).to eq "200"
      expect(response.headers["Content-Disposition"]).to match(/attachment; filename=.*oral_history_access_requests.*csv/)
      expect(response.media_type).to eq "text/csv"
      response_lines = response.body.lines
      expect(response_lines.count).to eq 6
      expect(response_lines[0]).to eq  "Date,Work,Name of patron,Email,Institution,Intended use\n"
      expect(response_lines[5]).to match  /Oral history interview with William John Bailey/
      expect(response_lines[5]).to match  /Patron 8/
      expect(response_lines[5]).to match  /patron@institution_8.com/
      expect(response_lines[5]).to match  /Institution 8/
      expect(response_lines[5]).to match  /I will write 8 books/
    end
  end
end
