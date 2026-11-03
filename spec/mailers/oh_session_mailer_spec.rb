require "rails_helper"

RSpec.describe OhSessionMailer, :type => :mailer do
  let(:patron) { create(:patron, email: "somebody@example.com") }

  let(:mail) do
    OhSessionMailer.
      with(patron: patron).
      sign_in_email
  end

  it "it has good metadata" do
    expect(mail.to).to eq ([patron.email])
    expect(mail.from).to eq(["oralhistory@sciencehistory.org"])
    expect(mail.subject).to eq "Your Science History Institute Oral Histories sign-in link"
  end

  it "includes an auto-login-link" do
    # mock the link to test it ends up in email? Since it's dynamic and different
    # every time you call it, I guess this works?
    allow_any_instance_of(Patron).to receive(:generate_token_for).with(:auto_login).and_return("TOKEN")

    expect(mail.body).to include("<a data-auto-login-link=\"true\" href=\"#{login_oral_history_session_url('TOKEN')}\">")
  end

  it "includes a unique reference header to avoid threading with other magic link emails" do
    expect(mail.header["references"]&.value).to match /Unique-[0-9a-f]+/
  end

  describe "registration_email" do
    let(:work) { create(:oral_history_work, :published, :available_by_request, availability_mode: :automatic_request) }
    let(:mail) { OhSessionMailer.with(patron: patron, work: work).registration_email }

    it "has a login link returning to the work, and count of registered oral histories" do
      allow_any_instance_of(Patron).to receive(:generate_token_for).with(:auto_login).and_return("TOKEN")

      expect(mail.to).to eq [patron.email]
      expect(mail.body).to include(CGI.escapeHTML(login_oral_history_session_url("TOKEN", return_to: work_path(work.friendlier_id))))
      expect(mail.body).to include("access to 1 oral histories")
    end
  end
end
