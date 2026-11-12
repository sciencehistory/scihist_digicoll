require "rails_helper"

describe "Patron login sessions", type: :request do
  let!(:oh_request) { create(:oral_history_request, delivery_status: "approved") }
  let(:patron) { oh_request.patron }
  let!(:token) { patron.generate_token_for(:auto_login) }

  def drop_session_cookie
    cookies.delete(Rails.application.config.session_options[:key])
  end

  it "magic link is reusable within 7 days, not after" do
    travel 6.days do
      get login_oral_history_session_path(token)
      expect(response).to redirect_to(oral_history_requests_path)
    end
    travel 8.days do
      get login_oral_history_session_path(token)
      expect(response).to redirect_to(new_oral_history_session_path)
    end
  end

  it "remember cookie restores login after session cookie lost" do
    get login_oral_history_session_path(token)
    expect(cookies["remember_patron_token"]).to be_present
    drop_session_cookie
    get oral_history_requests_path
    expect(response).to have_http_status(200)
  end

  it "remember cookie expires after 30 days" do
    get login_oral_history_session_path(token)
    drop_session_cookie
    travel 31.days do
      get oral_history_requests_path
      expect(response).to redirect_to(new_oral_history_session_path)
    end
  end

  it "session times out after 30 days inactivity once remember cookie gone" do
    get login_oral_history_session_path(token)
    cookies.delete("remember_patron_token")
    travel 31.days do
      # devise timeoutable redirects back to same page, now anonymous
      get oral_history_requests_path
      expect(response).to redirect_to(oral_history_requests_path)
      follow_redirect!
      expect(response).to redirect_to(new_oral_history_session_path)
    end
  end

  it "fresh magic link login works after a stale timed-out session" do
    get login_oral_history_session_path(token)
    cookies.delete("remember_patron_token")
    travel 31.days do
      get login_oral_history_session_path(patron.generate_token_for(:auto_login))
      get oral_history_requests_path
      expect(response).to have_http_status(200)
    end
  end

  describe "with staff also logged in" do
    let(:staff) { create(:admin_user) }

    it "patron sign out and timeout leave staff logged in" do
      sign_in staff
      get login_oral_history_session_path(token)
      delete oral_history_session_path
      get admin_works_path
      expect(response).to have_http_status(200)

      get login_oral_history_session_path(token)
      cookies.delete("remember_patron_token")
      travel 31.days do
        get oral_history_requests_path
        expect(response).to redirect_to(oral_history_requests_path)
        follow_redirect!
        expect(response).to redirect_to(new_oral_history_session_path)
        get admin_works_path
        expect(response).to have_http_status(200)
      end
    end
  end

  it "rotating session_token logs out everywhere" do
    get login_oral_history_session_path(token)
    patron.update!(session_token: SecureRandom.uuid)
    get oral_history_requests_path
    expect(response).not_to have_http_status(200)
  end
end
