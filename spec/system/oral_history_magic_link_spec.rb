require 'rails_helper'

describe "Login with Oral Histories magic link", queue_adapter: :inline do
  let(:requester_email) { Admin::OralHistoryRequesterEmail.create(email: "example@example.com") }

  it "can request a link which works to log in" do
    visit new_oral_history_session_path

    fill_in :email, with: requester_email.email
    click_on "Send me a login link"

    expect(page).to have_text("A sign-in link for your Oral Histories requests has been emailed to #{requester_email.email}")

    mail = ActionMailer::Base.deliveries.find { |m| m.to == [requester_email.email] }
    expect(mail).to be_present

    parsed_body = Nokogiri::HTML(mail.body.decoded)
    auto_login_link = parsed_body.at_css("a[data-auto-login-link]")["href"]

    visit auto_login_link

    # requests dashboard
    expect(page).to have_selector("h2", text: "Oral History Requests")
    expect(page).to have_text(requester_email.email)
  end
end
