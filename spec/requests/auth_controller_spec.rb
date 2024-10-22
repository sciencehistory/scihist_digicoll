require 'rails_helper'

# NOTE:
# System tests are slow and tend to be flaky. Many of these tests used to be
# in a system test (login_spec.rb) but this request test is faster and more reliable.
RSpec.describe AuthController, type: :request, queue_adapter: :test do

  # This is the user that gets looked up in the DB:
  let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', password: "goatgoat") }

  context "using Azure to log in" do

    # An authenticated email. This email address belongs to a person who has gotten authenticated.
    let(:incoming_email) { 'the_user@sciencehistory.org' }
  
    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:log_in_using_azure).and_return(true)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:azure_activedirectory_v2] = OmniAuth::AuthHash.new({
        :provider => 'azure_activedirectory_v2',
        :uid => '12345',
        :email => incoming_email,
        :info => OmniAuth::AuthHash::InfoHash.new({ email: incoming_email })
      })
    end
    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:azure_activedirectory_v2] = nil
    end

    context "admin user" do
      let(:work) { FactoryBot.create(:public_work, title: "Redirect to me")}
      it "can login and log out" do
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Signed in successfully/
        get admin_collections_path
        expect(response).to have_http_status(200)
        expect(response.body).to match /New Collection/
        delete destroy_user_session_path
        follow_redirect!
        expect(response.body).to match /Signed out successfully/
      end
    end
    context "SSO succeeds, but no account by that name in our DB" do
      let(:incoming_email) { 'some_other_user@sciencehistory.org' }
      it "can't log in" do
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response).to have_http_status(200)
        expect(response.body).to match /Digital Collections administrator/
      end
    end
    context "locked out user" do
      let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', password: "goatgoat", locked_out: true) }
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
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        get user_azure_activedirectory_v2_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Log in/
        expect(response.body).to match /logins are temporarily disabled/
      end
      it "kicked out if already logged in" do
        sign_in user
        get admin_works_path
        expect(response).to have_http_status(200)
        expect(response.body).to match /Works/
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        get admin_works_path
        follow_redirect!
        expect(response.body).to match /logins are temporarily disabled/
      end
    end
  end

  context "Without Azure" do
    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:log_in_using_azure).and_return(false)
    end
    it "can login" do
      get new_user_session_path
      expect(response).to have_http_status(200)
      post new_user_session_path, params: { user: {
          email: user.email,
          password: user.password,
        }
      }
      follow_redirect!
      expect(response.body).to match /Signed in/
    end
    context "locked out user" do
      it "can't log in" do
        user.update(locked_out: true)
        get new_user_session_path
        post new_user_session_path, params: { user: {
            email: user.email,
            password: user.password,
            remember_me: "0"
          }
        }
        follow_redirect!
        expect(response.body).to match /Sorry, your account is disabled/
      end

      it "kicked out if already logged in" do
        sign_in user
        user.update(locked_out: true)
        get admin_works_path
        follow_redirect!
        expect(response.body).to match /Sorry, your account is disabled/
      end
    end
    context "global lock-out" do
      it "can't log in" do
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        post new_user_session_path, params: { user: {
            email: user.email,
            password: user.password,
          }
        }
        follow_redirect!
        expect(response.body).to match /logins are temporarily disabled/
      end
      it "kicks out user even if already logged in" do
        sign_in user
        get admin_works_path
        expect(response).to have_http_status(200)
        expect(response.body).to match /Works/
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
        get admin_works_path
        expect(response).to have_http_status(302)
        follow_redirect!
        expect(response.body).to match /logins are temporarily disabled/
      end
    end
  end
end
