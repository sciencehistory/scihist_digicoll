require 'rails_helper'

RSpec.describe AuthController, type: :request, queue_adapter: :test do
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
  describe "dev environment" do
    context "admin user" do
      let(:work) { FactoryBot.create(:public_work, title: "Redirect to me")}
      it "can login and log out" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:dev_login).and_return('the_user@sciencehistory.org')
        get dev_login_path
        follow_redirect!
        expect(response.body).to match /Signed in successfully/
        get admin_collections_path
        expect(response.body).to match /New Collection/
        delete destroy_user_session_path
        follow_redirect!
        expect(response.body).to match /Signed out successfully/
      end
      it "can't click login button unless a dev login is defined" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:dev_login).and_return nil
        get root_path
        expect(response.body).to match /Dev log in unavailable/
      end

      it "does not allow log in unless you have a login defined" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:dev_login).and_return 'goat'
        get dev_login_path
        follow_redirect!
        expect(response.body).to match /Please set DEV_LOGIN to a valid email address/
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
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Signed in successfully/
         get admin_collections_path
         expect(response.body).to match /New Collection/
         delete destroy_user_session_path
         follow_redirect!
         expect(response.body).to match /Signed out successfully/
      end
      it "doesn't allow dev login" do
        get dev_login_path
        follow_redirect!
        expect(response.body).to match /Can.*t log you in this way./
      end
    end
    context "SSO succeeds, but no account by that name in our DB" do
      let(:incoming_email) { 'some_other_user@sciencehistory.org' }
      it "can't log in" do
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /couldn.*t find an account/
      end
    end
    context "locked out user" do
      let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', locked_out: true) }
      it "can't log in" do
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Sorry, this user is not allowed to log in./
      end
    end
    context "user is logged out mid-session" do
      it "locked out immediately" do
        get root_path
        expect(response.body).to match /Log in/
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Signed in successfully/
        expect(response.body).to match /Log out/
        user.update(locked_out: true)
        get root_path
        follow_redirect!
        expect(response.body).to match /your account is disabled/
        expect(response.body).to match /Log in/
      end
    end
    context "global lock-out" do
      it "can't log in" do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Log in/
        expect(response.body).to match /logins are temporarily disabled/
      end
      it "kicked out if already logged in" do
        sign_in user
        get admin_works_path
        expect(response.body).to match /Works/
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        get admin_works_path
        follow_redirect!
        expect(response.body).to match /logins are temporarily disabled/
      end
    end
  end
end
