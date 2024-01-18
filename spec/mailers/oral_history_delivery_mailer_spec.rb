require "rails_helper"

RSpec.describe OralHistoryDeliveryMailer, :type => :mailer do
  let(:mocked_token)  { "TOKEN" }

  before do
    # mock the link to test it ends up in email? Since it's dynamic and different
    # every time you call it, I guess this works?
    allow_any_instance_of(Admin::OralHistoryRequesterEmail).to receive(:generate_token_for).with(:auto_login).and_return("TOKEN")
  end

  describe "#approved_with_session_link_email" do
    let(:access_request) { create(:oral_history_request, delivery_status: "approved") }

    let(:mail) do
      OralHistoryDeliveryMailer.
        with(request: access_request).
        approved_with_session_link_email
    end

    it "it has good metadata" do
      expect(mail.to).to eq ([access_request.requester_email])
      expect(mail.from).to eq(["oralhistory@sciencehistory.org"])
      expect(mail.subject).to eq "Science History Institute: Access files for #{access_request.work.title}"
    end

    it "includes an auto-login-link and body" do
      expect(mail.body.raw_source).to include("<a data-auto-login-link=\"true\" href=\"#{login_oral_history_session_url('TOKEN')}\">")

      mail_body_html = Nokogiri::HTML(mail.body.raw_source)
      expect(mail_body_html).to have_text("Your request for files from #{access_request.work.title} has been approved.")
    end
  end

  describe "#rejected_with_session_link_email" do
    let(:custom_message) { "Sorry, impossible at this time" }
    let(:access_request) { create(:oral_history_request, delivery_status: "rejected", notes_from_staff: custom_message) }

    let(:mail) do
      OralHistoryDeliveryMailer.
        with(request: access_request).
        rejected_with_session_link_email
    end

    it "it has good metadata" do
      expect(mail.to).to eq ([access_request.requester_email])
      expect(mail.from).to eq(["oralhistory@sciencehistory.org"])
      expect(mail.subject).to eq "Science History Institute: Your request for #{access_request.work.title}"
    end

    it "includes an auto-login-link and body" do
      expect(mail.body.raw_source).to include("<a data-auto-login-link=\"true\" href=\"#{login_oral_history_session_url('TOKEN')}\">")

      mail_body_html = Nokogiri::HTML(mail.body.raw_source)
      expect(mail_body_html).to have_text("Unfortunately we could not approve your request for files from #{access_request.work.title} at this time.")
    end

    it "includes the custom message" do
      expect(mail.body.raw_source).to include(custom_message)
    end
  end
end



