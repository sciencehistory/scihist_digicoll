require 'rails_helper'

describe "Turnstile bot limiting", js:true do
  include WebmockTurnstileHelperMethods

  # We need an actual cache to keep track of rate limit, while in test we normally have nullstore
  before do
    memstore = ActiveSupport::Cache::MemoryStore.new
    allow(Rack::Attack.cache).to receive(:store).and_return(memstore)
  end

  let(:cf_turnstile_sitekey_pass) { "1x00000000000000000000AA" } # a test key
  let(:cf_turnstile_secret_key_pass) { "1x0000000000000000000000000000000AA" } # a testing key always passes
  let(:cf_turnstile_secret_key_fail) { "2x0000000000000000000000000000000AA" } # a testing key that produces failure

  let(:turnstile_failure_re) { /your traffic looks unusual/i }
  let(:turnstile_success_re) { /you searched for/i }

  let(:rate_limit_count) { 1 } # one hit then challenge

  # Temporarily change desired mocked config
  # Kinda hacky because we need to keep re-registering the tracks
  around(:each) do |example|
    orig_enabled = BotDetectController.enabled
    orig_sitekey = BotDetectController.cf_turnstile_sitekey
    orig_secretkey = BotDetectController.cf_turnstile_secret_key
    orig_ratelimitcount = BotDetectController.rate_limit_count

    BotDetectController.enabled = true
    BotDetectController.cf_turnstile_sitekey = cf_turnstile_sitekey
    BotDetectController.cf_turnstile_secret_key = cf_turnstile_secret_key
    BotDetectController.rate_limit_count = rate_limit_count

    BotDetectController.rack_attack_init

    example.run

    BotDetectController.enabled = orig_enabled

    BotDetectController.cf_turnstile_sitekey = orig_sitekey
    BotDetectController.cf_turnstile_secret_key = orig_secretkey
    BotDetectController.rate_limit_count = orig_ratelimitcount

    BotDetectController.rack_attack_init
  end

  describe "search" do
    describe "succesful challenge" do
      let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
      let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_pass }

      before do
        allow(Rails.logger).to receive(:info)
        stub_turnstile_success(request_body: {"secret"=>BotDetectController.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"})
      end

      it "smoke tests" do
        visit search_catalog_path(q: "foo")
        expect(page).to have_content(/you searched for/i)

        # on second try, we're gonna get redirected to bot check page
        visit search_catalog_path(q: "bar")
        expect(page).to have_content(/traffic control/i)

        # which eventually will redirect back to search.
        expect(page).to have_content(turnstile_success_re, wait: 4)
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
        expect(page).to have_content(/you searched for/i)

        # on second try, we're gonna get redirected to bot check page
        visit search_catalog_path(q: "bar")
        expect(page).to have_content(/traffic control/i)

        # which is going to get a failure message
        expect(page).to have_content(turnstile_failure_re, wait: 4)
        expect(Rails.logger).to have_received(:warn).with(/BotDetectController: Cloudflare Turnstile validation failed/)
      end
    end
  end

  describe "downloads" do
    let(:cf_turnstile_sitekey) { cf_turnstile_sitekey_pass }
    let(:cf_turnstile_secret_key) { cf_turnstile_secret_key_pass }

    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:cf_turnstile_downloads_enabled).and_return(true)

      stub_turnstile_success(request_body: {"secret"=>BotDetectController.cf_turnstile_secret_key, "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"})
    end

    let(:work) do
      create(
        :work, :published, members: [
          create(:asset_with_faked_file,
            title: "First asset",
            faked_derivatives: {},
            position: 0),
          ]
      )
    end

    it "provides turnstile captcha which leads to download" do
      visit work_path(work)

      click_button("Download", :match => :first)
      click_link("Original file")

      expect(page).to have_text("Traffic control and bot detection...")
      # There is no great way to test download actually happened!
      # And selenium may be showing picture in browser instead of downloading.
      # But we can test that the dialog eventually goes away, and there are no
      # browser errors

      browser_logs = page.driver.browser.logs.get(:browser)
      expect(browser_logs.collect { |l| l.level == "SERVERE"}).to be_empty, browser_logs.collect { |m| m.message }.inspect

      expect(page).not_to have_text("Traffic control and bot detection...")

      browser_logs = page.driver.browser.logs.get(:browser)
      expect(browser_logs.collect { |l| l.level == "SERVERE"}).to be_empty, browser_logs.collect { |m| m.message }.inspect

      # hopefully we're not on 403 error message from downloads!
      expect(page).not_to have_text("Denied")
    end
  end
end
