require 'rails_helper'

describe "Cart and Batch Edit" do
  include WebmockTurnstileHelperMethods

  # We need an actual cache to keep track of rate limit, while in test we normally have nullstore
  before do
    memstore = ActiveSupport::Cache::MemoryStore.new
    allow(Rack::Attack.cache).to receive(:store).and_return(memstore)
  end


  let(:cf_turnstile_sitekey_pass) { "1x00000000000000000000AA" } # a test key
  let(:cf_turnstile_secret_key_pass) { "1x0000000000000000000000000000000AA" } # a testing key always passes
  let(:cf_turnstile_secret_key_fail) { "2x0000000000000000000000000000000AA" } # a testing key that produces failure

  let(:rate_limit_count) { 1 } # one hit then challenge


  # Temporarily change desired mocked config
  # Kinda hacky because we need to keep re-registering the tracks
  around(:each) do |example|
    orig_sitekey = BotDetectController.cf_turnstile_sitekey
    orig_secretkey = BotDetectController.cf_turnstile_secret_key
    orig_ratelimitcount = BotDetectController.rate_limit_count

    BotDetectController.cf_turnstile_sitekey = cf_turnstile_sitekey
    BotDetectController.cf_turnstile_secret_key = cf_turnstile_secret_key
    BotDetectController.rate_limit_count = rate_limit_count

    BotDetectController.rack_attack_init

    example.run

    BotDetectController.cf_turnstile_sitekey = orig_sitekey
    BotDetectController.cf_turnstile_secret_key = orig_secretkey
    BotDetectController.rate_limit_count = orig_ratelimitcount

    BotDetectController.rack_attack_init
  end

  describe "succesful challenge" do
    let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
    let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_pass }

    before do
      allow(Rails.logger).to receive(:info)
      stub_turnstile_success(request_body: {"secret"=>BotDetectController.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"})
    end

    it "smoke tests" do
      visit search_catalog_path(q: "foo")
      expect(page).to have_content(/You Searched For/i) # one search results page

      # on second try, we're gonna get redirected to bot check page
      visit search_catalog_path(q: "bar")
      expect(page).to have_content("Traffic control and bot detection")

      # which eventually will redirect back to search
      expect(page).to have_content(/You Searched For/i)

      expect(Rails.logger).to have_received(:info).with(/BotDetectController: Cloudflare Turnstile challenge redirect/)
    end
  end

  describe "failed challenge" do
    let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
    let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_fail }

    before do
      allow(Rails.logger).to receive(:warn)
      stub_turnstile_failure(request_body: {"secret"=>BotDetectController.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"})
    end

    it "stays on page with failure" do
      visit search_catalog_path(q: "foo")
      expect(page).to have_content(/You Searched For/i) # one search results page

      # on second try, we're gonna get redirected to bot check page
      visit search_catalog_path(q: "bar")
      expect(page).to have_content("Traffic control and bot detection")

      # which is going to get a failure message
      expect(page).to have_content("Check failed. Sorry, something has gone wrong, or your traffic looks unusual to us. You can try refreshing this page to try again.")

      expect(Rails.logger).to have_received(:warn).with(/BotDetectController: Cloudflare Turnstile validation failed/)
    end
  end
end
