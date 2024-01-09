require "rails_helper"

describe OralHistorySessionsController, type: :controller, queue_adapter: :inline do
  let(:requester_email) { Admin::OralHistoryRequesterEmail.create(email: "nobody@example.com" ) }

  describe "#create" do
    it "sends a login link" do
      get :create, params: { email: requester_email.email }

      expect(response).to redirect_to root_path
      expect(flash[:notice]).to eq "A sign-in link for your Oral Histories requests has been emailed to #{requester_email.email}"

      email_delivery = ActionMailer::Base.deliveries.first
      expect(email_delivery.to).to eq [requester_email.email]
    end

    describe "for unknown email" do
      it "redirects to email entry form" do
        get :create, params: { email: "no_such_email@example.com" }

        expect(response).to redirect_to(new_oral_history_session_path)
        expect(flash[:auto_link_message]).to eq "Sorry, we have no email on record for no_such_email@example.com, check your entry?"
      end
    end
  end

  describe "#login" do
    let(:auto_login_link) { requester_email.generate_token_for(:auto_login) }

    it "authenticates and stores login" do
      get :login, params: { token: auto_login_link}

      expect(session[:oral_history_requester_id]).to eq requester_email.id

      expect(response).to redirect_to(oral_history_requests_path)
    end

    describe "with bad token" do
      it "does not authenticate" do
        get :login, params: { token: "bad token"}

        expect(session[:oral_history_requester_id]).to be nil

        expect(response).to redirect_to(new_oral_history_session_path)
        expect(flash[:auto_link_message]).to eq "Sorry, your link has expired or is not valid. Please enter your email, and we'll send you a new one."
      end
    end
  end

  describe "#new" do
    render_views

    let(:custom_message) { "this is a custom message" }

    it "includes custom message on login form" do
      get :new, flash: { auto_link_message: custom_message }

      expect(response).to have_http_status(200)
      expect(response.body).to include(custom_message)
    end
  end

  describe "#destroy" do
    it "signs out" do
      session[:oral_history_requester_id] = requester_email.id
      delete :destroy

      expect(session[:oral_history_requester_id]).to be nil
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to include("signed out")
    end
  end
end
