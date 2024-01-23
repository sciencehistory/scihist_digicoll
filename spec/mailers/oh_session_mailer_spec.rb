require "rails_helper"

RSpec.describe OhSessionMailer, :type => :mailer do
  let(:requester_email) { OralHistoryRequester.create(email: "somebody@example.com") }

  let(:mail) do
    OhSessionMailer.
      with(requester_email: requester_email).
      link_email
  end

  it "it has good metadata" do
    expect(mail.to).to eq ([requester_email.email])
    expect(mail.from).to eq(["oralhistory@sciencehistory.org"])
    expect(mail.subject).to eq "Sign-in to Science History Insitute Oral Histories Requests"
  end

  it "includes an auto-login-link" do
    # mock the link to test it ends up in email? Since it's dynamic and different
    # every time you call it, I guess this works?
    allow_any_instance_of(OralHistoryRequester).to receive(:generate_token_for).with(:auto_login).and_return("TOKEN")

    expect(mail.body).to include("<a data-auto-login-link=\"true\" href=\"#{login_oral_history_session_url('TOKEN')}\">")
  end

  it "includes a unique reference header to avoid threading with other magic link emails" do
    expect(mail.header["references"]&.value).to match /Unique-[0-9a-f]+/
  end
end
