require 'rails_helper'

describe "Login with Oral Histories magic link", queue_adapter: :inline do
  let(:approved_request) { create(:oral_history_request) }
  let(:requester) { approved_request.oral_history_requester }
  let(:oral_history_work) { approved_request.work }

  it "can request a link which works to log in" do
    visit new_oral_history_session_path

    fill_in :email, with: requester.email
    click_on "Send me a sign-in link"

    expect(page).to have_text("A sign-in link for your Oral Histories requests has been emailed to #{requester.email}")

    mail = ActionMailer::Base.deliveries.find { |m| m.to == [requester.email] }
    expect(mail).to be_present

    parsed_body = Nokogiri::HTML(mail.body.decoded)
    auto_login_link = parsed_body.at_css("a[data-auto-login-link]")["href"]

    visit auto_login_link

    # requests dashboard
    expect(page).to have_selector("h2", text: "Oral History Requests")
    expect(page).to have_text(requester.email)

    # Move to individual request page
    click_on oral_history_work.title

    expect(page).to have_selector("h3", text: oral_history_work.title)
    # basic sanity check, has a link for each asset
    (by_request, not_by_request) = oral_history_work.members.partition { |member| member.kind_of?(Asset) && !member.published? && member.oh_available_by_request? }

    # The logic for labelling links has gotten very convoluted, it's hard to check for
    # expected links and only expected links. Sorry!

    by_request.each do |asset|
      expected_label = asset.role == "transcript" ? "Transcript (Published Version)" : asset.title
      expect(page).to have_selector("a", text: expected_label)
    end

    not_by_request.each do |asset|
      expected_label = asset.role == "transcript" ? "Transcript (Published Version)" : asset.title
      expect(page).not_to have_selector("a", text: expected_label)
    end

    # logout
    visit oral_history_requests_path
    click_on "Sign out"
    # make sure we're really signed out
    expect(page).to have_text("You have been signed out")
    visit oral_history_requests_path
    expect(page).not_to have_selector("h2", text: "Oral History Requests")
    expect(page).to have_content("Please fill out your email address, and you will be emailed a sign-in link")
  end
end
