# Some explanation at https://sciencehistory.atlassian.net/wiki/spaces/HDC/pages/2645098498/Cloudflare+Turnstile+bot+detection
Rails.application.config.to_prepare do
config = BotChallengePage::BotChallengePageController.bot_challenge_config

  # allow rate_limit_count requests in rate_limit_period, before issuing challenge
  config.rate_limit_period = 12.hour
  config.rate_limit_count = 2 # seriously reduced to see if that helps

  # How long a challenge pass is good for
  config.session_passed_good_for = 24.hours

  config.enabled                 = ScihistDigicoll::Env.lookup(:cf_turnstile_enabled)
  config.cf_turnstile_sitekey    = ScihistDigicoll::Env.lookup(:cf_turnstile_sitekey)
  config.cf_turnstile_secret_key = ScihistDigicoll::Env.lookup(:cf_turnstile_secret_key)

  # any custom collection controllers or other controllers that offer search have to be listed here
  # to rate-limit them!
  config.rate_limited_locations = [
    '/catalog',
    '/focus',
    # we want to omit `/collections` list page, so we do these by controller
    { controller: "collection_show" },
    { controller: "collection_show_controllers/immigrants_and_innovation_collection" },
    { controller: "collection_show_controllers/oral_history_collection"},
    { controller: "collection_show_controllers/bredig_collection"}
  ]

  config.allow_exempt = ->(controller, config) {
    # Excempt any Catalog #facet action that looks like an ajax/fetch request, the redirect
    # ain't gonna work there, we just exempt it.
    #
    # sec-fetch-dest is set to 'empty' by browser on fetch requests, to limit us further;
    # sure an attacker could fake it, we don't mind if someone determined can avoid rate-limiting on this one action
    ( controller.params[:action].in?(["facet", "range_limit"]) &&
      controller.request.headers["sec-fetch-dest"] == "empty" &&
      controller.kind_of?(CatalogController)
    ) ||
    # Exempt honeybadger token from uptime checker
    # https://docs.honeybadger.io/guides/security/
    (
      ENV['HONEYBADGER_TOKEN'].present? &&
      controller.request.headers['Honeybadger-Token'] == ENV['HONEYBADGER_TOKEN']
    ) ||
    # Exempt a collection controller (or sub-class!) with _no query params_, we want to
    # let Google and other bots into colleciton home pages, even though they show search results.
    (
      controller.kind_of?(CollectionShowController) &&
      controller.respond_to?(:has_search_parameters?) &&
      !controller.has_search_parameters?
    ) ||
    ## exempt PDF original downloads, which are protected with an 'immediate' filter
    (
      controller.kind_of?(DownloadsController) &&
      controller.params[:file_category] == "pdf"
    )
  }

  config.after_blocked = ->(bot_detect_class) {
    logger.info "challenge blocked"
    request.env["bot_detect.blocked_for_challenge"] = true
  }

  BotChallengePage::BotChallengePageController.rack_attack_init
end
