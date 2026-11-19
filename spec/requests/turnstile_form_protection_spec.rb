require "rails_helper"

describe "Turnstile on patron registration and request forms", type: :request, queue_adapter: :test do
  let(:verify_url) { BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_validation_url }

  around do |example|
    orig_config = BotChallengePage::BotChallengePageController.bot_challenge_config.dup
    BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true
    BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_sitekey = "1x00000000000000000000AA"
    example.run
  ensure
    BotChallengePage::BotChallengePageController.bot_challenge_config = orig_config
  end

  def stub_verify(success:)
    stub_request(:post, verify_url).to_return(
      headers: { "Content-Type" => "application/json" },
      body: { success: success }.to_json
    )
  end

  def turnstile_placeholder
    Nokogiri::HTML(response.body).at_css("[data-trigger='scihist-auto-cf-turnstile']")
  end

  describe "registration" do
    let(:work) { create(:oral_history_work, :available_by_request, availability_mode: :automatic_request) }
    let(:params) do
      {
        work_friendlier_id: work.friendlier_id,
        patron: { email: "new-patron@example.com", name: "Pat Ron" }
      }
    end

    it "form has turnstile placeholder" do
      get oral_history_registration_form_path(work.friendlier_id)
      expect(turnstile_placeholder["data-sitekey"]).to be_present
    end

    it "without passing turnstile, re-renders form and creates nothing" do
      stub_verify(success: false)
      expect {
        post register_oral_history_path, params: params.merge("cf-turnstile-response" => "bad")
      }.not_to change { Patron.count }
      expect(response).to have_http_status(200)
      expect(response.body).to include(CGI.escapeHTML(TurnstileFormProtection::FAILED_MESSAGE))
      expect(turnstile_placeholder).to be_present
      expect(ActionMailer::Base.deliveries.size + enqueued_jobs.size).to eq 0
    end

    it "in modal, failure returns form with error and fresh placeholder" do
      stub_verify(success: false)
      post register_oral_history_path, params: params.merge("cf-turnstile-response" => "bad"), xhr: true
      expect(response).to have_http_status(200)
      expect(response.body).to include(CGI.escapeHTML(TurnstileFormProtection::FAILED_MESSAGE))
      expect(turnstile_placeholder).to be_present
    end

    it "with passing turnstile, registers" do
      stub_verify(success: true)
      expect {
        post register_oral_history_path, params: params.merge("cf-turnstile-response" => "good")
      }.to change { Patron.count }.by(1)
    end
  end

  describe "reviewed request" do
    let(:work) { create(:oral_history_work, :available_by_request) }
    let(:params) do
      {
        oral_history_request: {
          work_friendlier_id: work.friendlier_id,
          patron_name: "joe",
          intended_use: "I just like turtles"
        },
        patron_email: "joe@example.com"
      }
    end

    it "form has turnstile placeholder" do
      get oral_history_request_form_path(work.friendlier_id)
      expect(turnstile_placeholder["data-sitekey"]).to be_present
    end

    it "signed-in patron keeps intended use when form re-rendered" do
      sign_in create(:patron)
      post request_oral_history_path, params: params
      expect(response.body).to include(CGI.escapeHTML(TurnstileFormProtection::FAILED_MESSAGE))
      expect(Nokogiri::HTML(response.body).at_css("textarea[name='oral_history_request[intended_use]']").text.strip).to eq "I just like turtles"
    end

    it "with passing turnstile, creates request" do
      stub_verify(success: true)
      expect {
        post request_oral_history_path, params: params.merge("cf-turnstile-response" => "good")
      }.to change { OralHistoryRequest.count }.by(1)
    end
  end
end
