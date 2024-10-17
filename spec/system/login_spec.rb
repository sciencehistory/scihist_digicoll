require 'rails_helper'
RSpec.describe "Logins", type: :system do

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
  context "dev" do
    context "admin user" do
      let(:work) { FactoryBot.create(:public_work, title: "Redirect to me")}
      it "can login and log out" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:dev_login).and_return('the_user@sciencehistory.org')
        visit root_path
        click_on "Dev log in"
        expect(page).to have_text("Signed in successfully")
        visit admin_collections_path
        expect(page).to have_text("New Collection")
        click_on "Logout"
        expect(page).to have_text("Signed out successfully")
      end
      it "does not allow log in unless you have a login defined" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:dev_login).and_return 'goat'
        visit root_path
        click_on "Dev log in"
        expect(page).to have_text("Please set DEV_LOGIN to a valid email address")
      end
      it "Can't log in unless you have a login defined" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:dev_login).and_return nil
        visit root_path
        expect(page).to have_text("DEV LOG IN UNAVAILABLE")
      end
    end
  end
  context "staging or prod" do
    before do
      allow(ScihistDigicoll::Env).to receive(:staging?).and_return('true')
    end
    context "admin user" do
      let(:work) { FactoryBot.create(:public_work, title: "Redirect to me")}
      it "can login and log out" do
        visit root_path
        click_on "Log in"
        expect(page).to have_text("Signed in successfully")
        visit admin_collections_path
        expect(page).to have_text("New Collection")
        click_on "Logout"
        expect(page).to have_text("Signed out successfully")
      end
      it "redirects after login to where you were before" do
        visit work_path(work)
        expect(page).to have_text("Redirect to me")
        click_on "Log in"
        expect(page).to have_text("Signed in successfully")
        expect(page).to have_text("Redirect to me")
      end
      it "doesn't allow dev login" do
        visit dev_login_path
        expect(page).to have_text("Can't log you in this way.")
      end
    end
    context "SSO succeeds, but no account by that name in our DB" do
      let(:incoming_email) { 'some_other_user@sciencehistory.org' }
      it "can't log in" do
        visit root_path
        click_on "Log in"
        expect(page).to have_text("couldn't find an account")
      end
    end

    context "locked out user" do
      let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', locked_out: true) }
      it "can't log in" do
        visit root_path
        click_on "Log in"
        expect(page).to have_text("Sorry, this user is not allowed to log in.")
      end
    end

    context "user is logged out mid-session" do
      it "locked out immediately" do
        visit root_path
        expect(page).to have_text("LOG IN")
        click_on "Log in"
        expect(page).to have_text("Signed in successfully")
        expect(page).to have_text("LOG OUT")
        user.update(locked_out: true)
        visit root_path
        expect(page).to have_text("your account is disabled")
        expect(page).to have_text("LOG IN")
      end
    end
    context "global lock-out" do
      it "can't log in" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        visit root_path
        expect(page).to have_text("LOG IN")
        click_on "Log in"
        expect(page).to have_text("logins are temporarily disabled")
      end
      it "kicked out if already logged in" do
        sign_in user
        visit admin_works_path
        expect(page).to have_text("Works")
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        visit admin_works_path
        expect(page).to have_text("logins are temporarily disabled")
      end
    end
  end
end
