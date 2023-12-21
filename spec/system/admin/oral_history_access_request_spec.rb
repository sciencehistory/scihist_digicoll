require 'rails_helper'

RSpec.describe "Oral History Access Request Administration", :logged_in_user, type: :system, queue_adapter: :test  do
  let!(:work) do
    create(:oral_history_work, :available_by_request, available_by_request_mode: :manual_review, published: true)
  end

  context "A request exists for a manual_review work" do
    let!(:oh_request) { Admin::OralHistoryAccessRequest.create!(
      patron_name: "George Washington Carver",
      oral_history_requester_email: Admin::OralHistoryRequesterEmail.create_or_find_by(email: "george@example.org"),
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
