# Some explanation at https://sciencehistory.atlassian.net/wiki/spaces/HDC/pages/2645098498/Cloudflare+Turnstile+bot+detection
BotChallengePage.configure do |config|
  # How long a challenge pass is good for
  config.session_passed_good_for = 24.hours

  config.enabled                 = ScihistDigicoll::Env.lookup(:cf_turnstile_enabled)
  config.cf_turnstile_sitekey    = ScihistDigicoll::Env.lookup(:cf_turnstile_sitekey)
  config.cf_turnstile_secret_key = ScihistDigicoll::Env.lookup(:cf_turnstile_secret_key)


  config.skip_when = ->(config) {
    # Exempt honeybadger token to allow HB uptime checker in
    # https://docs.honeybadger.io/guides/security/
    (
      ENV['HONEYBADGER_TOKEN'].present? &&
      controller.request.headers['Honeybadger-Token'] == ENV['HONEYBADGER_TOKEN']
    )
  }

  config.after_blocked = ->(bot_detect_class) {
    # used as signal for our logging configuration, to omit requests that had a
    # bot challenge from being in our normal logs, as we were filling up
    # our log quota in papertrail.
    request.env["bot_detect.blocked_for_challenge"] = true

    # But log it in our local DB instead, where we have no quota.
    BotChallengedRequest.save_from_request!(request)
  }
end
