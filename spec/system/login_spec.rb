require 'rails_helper'
RSpec.describe "Logins", type: :system do
  # NOTE:
  # System tests are slow and tend to be flaky, so please try
  # putting your test in spec/requests/auth_controller_spec.rb first.
  # An authenticated email. This email address belongs to a person who has gotten authenticated.
  let(:incoming_email) { 'the_user@sciencehistory.org' }
  # This is the user that gets looked up in the DB:
  let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org') }
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:azure_activedirectory_v2] = OmniAuth::AuthHash.new({
      :provider => 'azure_activedirectory_v2',
      :uid => '12345', :email => incoming_email,
      :info => OmniAuth::AuthHash::InfoHash.new({ email: incoming_email })
    })
  end
  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:azure_activedirectory_v2] = nil
  end
  context "staging or prod" do
    before do
      allow(ScihistDigicoll::Env).to receive(:staging?).and_return('true')
    end
    context "admin user" do
      let(:work) { FactoryBot.create(:public_work, title: "Redirect to me")}
      it "redirects after login to where you were before" do
        visit work_path(work)
        expect(page).to have_text("Redirect to me")
        click_on "Log in"
        expect(page).to have_text("Signed in successfully")
        expect(page).to have_text("Redirect to me")
      end
    end
  end
end