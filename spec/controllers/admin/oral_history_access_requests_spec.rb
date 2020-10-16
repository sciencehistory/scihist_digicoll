require 'rails_helper'
RSpec.describe Admin::OralHistoryAccessRequestsController, :logged_in_user, type: :controller do
  describe "Oral History Access Request List Controller", logged_in_user: :admin do
    let(:access_request_array) do
        (1..10).to_a.map do |i|
          Admin::OralHistoryAccessRequest.new(
            created_at: Time.now() - 100000 * ( i + 1 ),
            patron_name: "Patron #{i}",
            patron_email: "patron@institution_#{i}.com",
            patron_institution: "Institution #{i}",
            intended_use: "I will write #{i} books.",
          )
      end
    end

    it "allows you to download the report" do
      post :report
      expect(response.code).to eq "200"
    end
  end
end
