require 'rails_helper'

RSpec.describe "Oral History Access Request Administration", :logged_in_user, type: :system, queue_adapter: :test  do
  let(:preview_pdf) { create(:asset_with_faked_file, :pdf, published: true) }
  let(:protected_pdf) { create(:asset_with_faked_file, :pdf, published: false, oh_available_by_request: true) }
  let(:protected_mp3) { create(:asset_with_faked_file, :mp3, published: false, oh_available_by_request: true) }

  let!(:work) do
    create(:oral_history_work, published: true).tap do |work|
      work.members << preview_pdf
      work.members << protected_pdf
      work.members << protected_mp3

      work.representative =  preview_pdf
      work.save!

      work.oral_history_content!.update(available_by_request_mode: :manual_review)
    end
  end


  context "A request exists for a manual_review work" do
    let!(:oh_request) { Admin::OralHistoryAccessRequest.create!(
      patron_name: "George Washington Carver",
      patron_email: "george@example.org",
      patron_institution: "Tuskegee Institute",
      intended_use: "Recreational reading.",
      work: work
    )}

    it "can approve" do
      visit admin_oral_history_access_requests_path

      relevant_table_row = find("tr", text: oh_request.intended_use)

      within(relevant_table_row) do
        click_link "pending"
      end

      expect(page).to have_text("Oral History Access Request")
      fill_in("Message to patron", with: "Hope you enjoy this!\r\n\r\nIt's a good one!")
      click_on "Approve"

      expect(page).to have_text("Approve email was sent")

      expect(oh_request.reload.delivery_status).to eq("approved")

      # not a great way to do this, but it tests at least something.
      enqueued_mail_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find {|h| h["job_class"] == "ActionMailer::MailDeliveryJob"}
      expect(enqueued_mail_job).to be_present
      expect(enqueued_mail_job["arguments"][0..1]). to eq(["OralHistoryDeliveryMailer", "oral_history_delivery_email"])
    end

    it "can reject" do
      visit admin_oral_history_access_requests_path

      relevant_table_row = find("tr", text: oh_request.intended_use)

      within(relevant_table_row) do
        click_link "pending"
      end

      expect(page).to have_text("Oral History Access Request")
      fill_in("Message to patron", with: "Sorry, you can't have this.")
      click_on "Reject"

      expect(page).to have_text("Reject email was sent")

      expect(oh_request.reload.delivery_status).to eq("rejected")

      # not a great way to do this, but it tests at least something.
      enqueued_mail_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find {|h| h["job_class"] == "ActionMailer::MailDeliveryJob"}
      expect(enqueued_mail_job).to be_present
    end
  end
end
