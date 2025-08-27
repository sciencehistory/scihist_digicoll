require 'rails_helper'

# This func is in a gem now, but we leave one local test here just to make sure it's still working?
describe "Turnstile bot limiting", js:true do
  include WebmockTurnstileHelperMethods

  let(:cf_turnstile_sitekey_pass) { "1x00000000000000000000AA" } # a test key
  let(:cf_turnstile_secret_key_pass) { "1x0000000000000000000000000000000AA" } # a testing key always passes
  let(:cf_turnstile_secret_key_fail) { "2x0000000000000000000000000000000AA" } # a testing key that produces failure

  let(:turnstile_failure_re) { /your traffic looks unusual/i }
  let(:turnstile_success_re) { /you searched for/i }

  # Temporarily change desired mocked config
  # Kinda hacky because we need to keep re-registering the tracks
  around(:each) do |example|
    orig_config = BotChallengePage::BotChallengePageController.bot_challenge_config.dup

    # Make sure we have a memory store to actually keep track of rate, and a fresh one that resets every test
    BotChallengePage::BotChallengePageController.bot_challenge_config.store = ActiveSupport::Cache::MemoryStore.new

    BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true
    BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_sitekey = cf_turnstile_sitekey
    BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key = cf_turnstile_secret_key

    example.run

    BotChallengePage::BotChallengePageController.bot_challenge_config = orig_config
  end

  describe "succesful challenge" do
    let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
    let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_pass }

    before do
      allow(Rails.logger).to receive(:info)
      stub_turnstile_success(request_body: {"secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"})
    end

    it "smoke tests" do
      visit search_catalog_path(q: "foo")
      expect(page).to have_content(/you searched for/i)

      # on second try, we're gonna get redirected to bot check page
      visit search_catalog_path(q: "bar")
      expect(page).to have_content(/traffic control/i)

      # which eventually will redirect back to search.
      expect(page).to have_content(turnstile_success_re, wait: 4)
    end
  end
end
