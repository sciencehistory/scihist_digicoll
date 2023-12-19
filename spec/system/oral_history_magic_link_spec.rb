require 'rails_helper'

describe "Login with Oral Histories magic link", queue_adapter: :inline do
  let(:approved_request) { create(:oral_history_access_request) }
  let(:requester_email) { approved_request.oral_history_requester_email }
  let(:oral_history_work) { approved_request.work }

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

    # Move to individual request page
    click_on oral_history_work.title
    expect(page).to have_selector("h2", text: oral_history_work.title)
    # basic sanity check, has a link for each asset
    (by_request, not_by_request) = oral_history_work.members.partition { |member| member.kind_of?(Asset) && !member.published? && member.oh_available_by_request? }

    by_request.each do |asset|
      expect(page).to have_selector("a", text: /#{DownloadFilenameHelper.filename_base_for_asset(asset)}/)
    end

    not_by_request.each do |asset|
      expect(page).not_to have_selector("a", text: /#{DownloadFilenameHelper.filename_base_for_asset(asset)}/)
    end
  end
end
