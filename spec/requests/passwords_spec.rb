require 'rails_helper'

RSpec.describe "passwords", type: :request, queue_adapter: :test do

  let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', password: "goatgoat") }

  context "using Microsoft SSO to log in" do
    # An authenticated email. This email address belongs to a person who has gotten authenticated.
    let(:incoming_email) { 'the_user@sciencehistory.org' }
    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:log_in_using_microsoft_sso).and_return(true)
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

    describe "reset password" do
      it "refuses" do
        get new_user_password_path
        follow_redirect!
        expect(response.body).to match /Passwords are managed in Microsoft SSO now/
      end
    end
    describe "edit password" do
      it "refuses" do
        get edit_user_password_path(reset_password_token:"abcde")
        follow_redirect!
        expect(response.body).to match /Passwords are managed in Microsoft SSO now/
      end
    end
    describe "update password" do
      it "refuses" do
        put '/users/password'
        follow_redirect!
        expect(response.body).to match /Passwords are managed in Microsoft SSO now/
      end
    end
    describe "create password" do
      it "refuses" do
        post '/users/password'
        follow_redirect!
        expect(response.body).to match /Passwords are managed in Microsoft SSO now/
      end
    end
  end

  context "Without Microsoft SSO (smoke tests)" do
    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:log_in_using_microsoft_sso).and_return(false)
      Rails.application.reload_routes!
    end
    after do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      Rails.application.reload_routes!
    end

    # This is going to the users controller.
    describe "Request to reset password" do
      it "routes to the devise password controller" do
        get new_user_password_path
        expect(response.body).to match /Send me reset password instructions/
      end
    end
    describe "Password reset request for a particular user" do
      it "Should set the reset password token" do
        sign_in user
        expect(user.reset_password_token).to be nil
        post send_password_reset_admin_user_path(id: user.id)
        expect(user.reload.reset_password_token).to be_a String
        follow_redirect!
        expect(response.body).to match /Password reset email sent/
      end
    end
    describe "edit password" do
      it "routes to the devise password controller" do
        get edit_user_password_path(reset_password_token:"abcde")
        expect(response.body).to match /Change your password/
        expect(response.body).to match /New password/
      end
    end
    describe "update password" do
      it "routes to the devise password controller" do
        put '/users/password'
        expect(response).to have_http_status(200)
        expect(response.body).to match /Change your password/
      end
    end
    describe "create password" do
      it "routes to the devise password controller" do
        post '/users/password'
        expect(response).to have_http_status(200)
        expect(response.body).to match /1 error prohibited this user from being saved/
      end
    end
  end
end
