require 'rails_helper'

# NOTE:
# System tests are slow and tend to be flaky. Many of these tests used to be
# in a system test (login_spec.rb) but this request test is faster and more reliable.
RSpec.describe AuthController, type: :request, queue_adapter: :test do
  include Rails.application.routes.url_helpers

  # This is the user that gets looked up in the DB:
  let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', password: "goatgoat") }

  context "using Microsoft SSO to log in" do

    # An authenticated email. This email address belongs to a person who has gotten authenticated.
    let(:incoming_email) { 'the_user@sciencehistory.org' }

    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:log_in_using_microsoft_sso).and_return(true)

      # Reload_routes! takes on the order of 10 milliseconds.
      #
      # Not sure why we need to call it TWICE to have it work right including
      # reliable route helpers.
      Rails.application.reload_routes!
      Rails.application.reload_routes!

      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:entra_id] = OmniAuth::AuthHash.new({
        :provider => 'entra_id',
        :uid => '12345',
        :email => incoming_email,
        :info => OmniAuth::AuthHash::InfoHash.new({ email: incoming_email })
      })
    end
    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:entra_id] = nil
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      Rails.application.reload_routes!
    end

    context "admin user" do
      let(:work) { FactoryBot.create(:public_work, title: "Redirect to me")}
      it "can login" do
        get user_entra_id_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Signed in successfully/
        get admin_collections_path
        expect(response).to have_http_status(200)
        expect(response.body).to match /New Collection/
      end
    end

    describe "logout" do
      it "logs the user out, then browser to microsoft logout" do
        sign_in user
        get admin_works_path
        expect(response).to have_http_status(200)
        get logout_path
        expect(response.headers['location']).to eq "#{OmniAuth::Strategies::EntraId::BASE_URL}/common/oauth2/v2.0/logout?post_logout_redirect_uri=#{ScihistDigicoll::Env.lookup(:app_url_base)}/"
        get admin_collections_path
        expect(response).to have_http_status(302)
        follow_redirect!
        expect(response.body).to match /You don.*t have permission/
      end
    end
    context "SSO succeeds, but no account by that name in our DB" do
      let(:incoming_email) { 'some_other_user@sciencehistory.org' }
      it "can't log in" do
        get user_entra_id_omniauth_callback_path
        follow_redirect!
        expect(response).to have_http_status(200)
        expect(response.body).to match /Digital Collections administrator/
      end
    end
    context "locked out user" do
      let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', password: "goatgoat", locked_out: true) }
      it "can't log in" do
        get user_entra_id_omniauth_callback_path
        follow_redirect!
        expect(response.body).to match /Sorry, this user is not allowed to log in./
      end
    end
    context "user is logged out mid-session" do
      it "locked out immediately" do
        get root_path
        expect(response.body).to match /Log in/
        get user_entra_id_omniauth_callback_path
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
        get user_entra_id_omniauth_callback_path
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

  context "Without Microsoft SSO - use password login" do
    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:log_in_using_microsoft_sso).and_return(false)
      Rails.application.reload_routes!
    end
    after do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      Rails.application.reload_routes!
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
