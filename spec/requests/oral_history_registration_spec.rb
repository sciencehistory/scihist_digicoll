require "rails_helper"

describe "Oral History patron registration", type: :request, queue_adapter: :test do
  let(:work) { create(:oral_history_work, :available_by_request, availability_mode: :automatic_request) }
  let(:email) { "new-patron@example.com" }
  let(:registration_params) do
    {
      work_friendlier_id: work.friendlier_id,
      patron: { email: email, name: "Pat Ron", institution: "Some U", registration_reason: "research" }
    }
  end

  def registration_link_from(mail)
    Nokogiri::HTML(mail.body.decoded).at_css("a[data-auto-login-link]")["href"]
  end

  it "work page Get Access button links to registration" do
    work.update!(published: true)
    get work_path(work.friendlier_id)
    expect(response.body).to include(%{href="#{oral_history_registration_form_path(work.friendlier_id)}"})
  end

  it "shows the registration form" do
    get oral_history_registration_form_path(work.friendlier_id)
    expect(response).to have_http_status(200)
    expect(response.body).to include("Reason for registering")
  end

  it "404s for reviewed_request works" do
    reviewed_work = create(:oral_history_work, :available_by_request, availability_mode: :reviewed_request)
    expect {
      get oral_history_registration_form_path(reviewed_work.friendlier_id)
    }.to raise_error(ActionController::RoutingError)
  end

  it "request form redirects automatic_request works to registration" do
    get oral_history_request_form_path(work.friendlier_id)
    expect(response).to redirect_to(oral_history_registration_form_path(work.friendlier_id))
  end

  describe "new patron" do
    it "creates unconfirmed patron, and emailed link confirms and returns to work", queue_adapter: :inline do
      post register_oral_history_path, params: registration_params
      expect(response).to redirect_to(work_path(work.friendlier_id))
      expect(flash[:success]).to include("We've sent an email to #{email}")

      patron = Patron.find_by!(email: email)
      expect(patron.name).to eq "Pat Ron"
      expect(patron.institution).to eq "Some U"
      expect(patron.registration_reason).to eq "research"
      expect(patron).not_to be_confirmed

      mail = ActionMailer::Base.deliveries.find { |m| m.to == [email] }
      expect(mail.subject).to eq "Confirm your Science History Institute registration"

      get registration_link_from(mail)
      expect(response).to redirect_to(work_path(work.friendlier_id))
      expect(patron.reload).to be_confirmed

      # now signed in, so registration redirects back to work
      get oral_history_registration_form_path(work.friendlier_id)
      expect(response).to redirect_to(work_path(work.friendlier_id))
    end

    it "re-renders form without creating patron when name missing" do
      expect {
        post register_oral_history_path, params: registration_params.deep_merge(patron: { name: "" })
      }.not_to change { Patron.count }
      expect(response).to have_http_status(200)
      expect(response.body).to include("Name can&#39;t be blank")
    end
  end

  describe "existing unconfirmed patron" do
    let!(:patron) { create(:patron, email: email, name: "Original") }

    it "sends registration email without changing stored details" do
      expect {
        post register_oral_history_path, params: registration_params
      }.to have_enqueued_mail(OhSessionMailer, :registration_email)

      expect(patron.reload.name).to eq "Original"
      expect(patron.registration_reason).to be_nil
    end
  end

  describe "existing confirmed patron" do
    let!(:patron) { create(:patron, email: email, name: "Original", confirmed_at: Time.current) }

    it "sends a sign-in link without changing stored details" do
      expect {
        post register_oral_history_path, params: registration_params
      }.to have_enqueued_mail(OhSessionMailer, :sign_in_email)

      expect(flash[:success]).to include("You are already registered")
      expect(patron.reload.name).to eq "Original"
    end

    it "sign-in link returns to the work", queue_adapter: :inline do
      post register_oral_history_path, params: registration_params

      mail = ActionMailer::Base.deliveries.find { |m| m.to == [email] }
      get registration_link_from(mail)
      expect(response).to redirect_to(work_path(work.friendlier_id))
    end
  end

  describe "login return_to" do
    let(:patron) { create(:patron, email: email) }
    let(:token) { patron.generate_token_for(:auto_login) }

    it "ignores a non-local return_to" do
      get login_oral_history_session_path(token, return_to: "//evil.example.com/")
      expect(response).to redirect_to(oral_history_requests_path)
    end
  end
end
