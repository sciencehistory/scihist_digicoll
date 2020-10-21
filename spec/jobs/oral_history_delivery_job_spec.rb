require 'rails_helper'

describe "OralHistoryDeliveryJob" do
  let(:request) { Admin::OralHistoryAccessRequest.create!(
      created_at: Time.parse("2020-10-01"),
      patron_name: "Patron name",
      patron_email: "patron@institution.com",
      patron_institution: "Institution",
      intended_use: "I will write so many books.",
      work: create(:oral_history_work)
    )
  }
  let(:job) { OralHistoryDeliveryJob.new(request) }

  describe "with an oral history" do
    it "enqueues the mail" do
    job.perform_now
  end

  end
end
