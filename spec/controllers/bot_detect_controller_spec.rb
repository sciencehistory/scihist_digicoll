require 'rails_helper'

RSpec.describe BotDetectController, type: :controller do
  include WebmockTurnstileHelperMethods

  describe "#verify_challenge" do
    it "handles turnstile success" do
      turnstile_response = stub_turnstile_success

      post :verify_challenge, params: { cf_turnstile_response: "XXXX.DUMMY.TOKEN.XXXX" }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.to_json

      expect(session[BotDetectController.session_passed_key]).to be_present
      expect(Time.new(session[BotDetectController.session_passed_key])).to be_within(60).of(Time.now.utc)
    end

    it "handles turnstile failure" do
      turnstile_response = stub_turnstile_failure

      post :verify_challenge, params: { cf_turnstile_response: "XXXX.DUMMY.TOKEN.XXXX" }
      expect(response.status).to be 200
      expect(response.body).to eq turnstile_response.to_json

      expect(session[BotDetectController.session_passed_key]).not_to be_present
    end
  end
end
