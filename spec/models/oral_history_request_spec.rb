require 'rails_helper'

describe OralHistoryRequest, type: :model do

  let(:access_request) do
    OralHistoryRequest.create!(
      patron_name: "Patron",
      oral_history_requester: OralHistoryRequester.create_or_find_by(email: "patron@institution.com"),
      intended_use: "I will write 10 books.",
      work: create(:oral_history_work)
    )
  end

  let(:access_request_with_no_oh_number) do
    work = access_request.work
    work.external_id = work.external_id.select {|id| id.attributes["category"] == "bib"}
    work.save!
    access_request
  end

  it "figures out the OH number" do
    expect(access_request.oral_history_number).to eq '0012'
  end

  it "returns nil if there is no OH number; no error" do
    expect(access_request_with_no_oh_number.work.external_id.count).to eq 1
    expect(access_request_with_no_oh_number.work.external_id.first.attributes['category']).to eq 'bib'
    expect(access_request_with_no_oh_number.oral_history_number).to be_nil
  end

  it "sets delivery_status_changed_at when delivery_status is set" do
    expect(access_request.delivery_status_changed_at).to be nil

    access_request.delivery_status = "approved"
    access_request.save!

    expect(access_request.delivery_status_changed_at).to be_present
  end
end
