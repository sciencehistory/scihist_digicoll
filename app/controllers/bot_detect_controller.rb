class BotDetectController < ApplicationController
  # Config for bot detection is held here in class_attributes, kind of wonky, but it works
  class_attribute :env_challenge_trigger_key, default: "bot_detect.should_challenge"

  # up to rate_limit_count requests in rate_limit_period before challenged
  class_attribute :rate_limit_period, default: 1.hour
  class_attribute :rate_limit_count, default: 3

  # discriminator is how we batch requests for counting rate limit, ordinarily by ip,
  # but we could expand to subnet instead, or use user-agent or whatever. If it returns
  # nil, then won't be tracked.
  class_attribute :rate_limit_discriminator, default: ->(req) { req.ip }
  class_attribute :rate_limited_paths, default: [  # regexp
                                                  %r{\A/catalog([/?]|\Z)}
                                                ]

  class_attribute :cf_turnstile_sitekey , default: "1x00000000000000000000AA" # a testing key that always passes
  class_attribute :cf_turnstile_secret_key, default: "1x0000000000000000000000000000000AA" # a testing key always passes
  # '3x00000000000000000000FF' # testing, manual check required

  class_attribute :cf_turnstile_js_url, default: "https://challenges.cloudflare.com/turnstile/v0/api.js"
  class_attribute :cf_turnstile_validation_url, default:  "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  class_attribute :cf_timeout, default: 3 # max timeout seconds waiting on Cloudfront Turnstile api
  helper_method :cf_turnstile_js_url, :cf_turnstile_sitekey

  # key stored in Rails session object with channge passed confirmed
  class_attribute :session_passed_key, default: "bot_detection-passed"
  # how long is a challenge pass good for before re-challenge?
  class_attribute :session_passed_good_for, default: 24.hours


  # perhaps in an initializer, and after changing any config, run:
  #
  #     Rails.application.config.to_prepare do
  #       BotDetectController.rack_attack_init
  #     end
  def self.rack_attack_init
    ## Turnstile bot detection throttling
    #
    # for paths matched by `rate_limited_paths`, after over rate_limit count requests in rate_limit_period,
    # token will be stored in rack env instructing challenge is required.
    #
    # For actual challenge, need before_action in controller.
    #
    # You could rate limit detect on wider paths than you actually challenge on, or the same. You probably
    # don't want to rate-limit detect on narrower list of paths than you challenge on!
    Rack::Attack.track("bot_detect/rate_exceeded",
        limit: self.rate_limit_count,
        period: self.rate_limit_period) do |req|

      if self.rate_limited_paths.any? { |re| re =~ req.path }
        self.rate_limit_discriminator.call(req)
      end
    end

    ActiveSupport::Notifications.subscribe("track.rack_attack") do |_name, _start, _finish, request_id, payload|
      rack_request = payload[:request]
      rack_env     = rack_request.env
      match_name = rack_env["rack.attack.matched"]  # name of rack-attack rule

      if match_name == "bot_detect/rate_exceeded"
        match_data   = rack_env["rack.attack.match_data"]
        match_data_formatted = match_data.slice(:count, :limit, :period).map { |k, v| "#{k}=#{v}"}.join(" ")
        discriminator = rack_env["rack.attack.match_discriminator"] # unique key for rate limit, usually includes ip

        rack_env[self.env_challenge_trigger_key] = true
      end
    end
  end


  def challenge
  end

  def verify_challenge
    body = {
      secret: self.cf_turnstile_secret_key,
      response: params["cf_turnstile_response"],
      remoteip: request.remote_ip
    }

    http = HTTP.timeout(timeout: self.cf_timeout)
    response = http.post(self.cf_turnstile_validation_url,
      json: body)

    result = response.parse
    # {"success"=>true, "error-codes"=>[], "challenge_ts"=>"2025-01-06T17:44:28.544Z", "hostname"=>"example.com", "metadata"=>{"result_with_testing_key"=>true}}

    if result["success"]
      # mark it as succesful in session, and record time. They do need a session/cookies
      # to get through the challenge.
      session[self.session_passed_key] = Time.now.utc.iso8601
    end

    # let's just return the whole thing to client? Is there anything confidential there?
    render json: result
  rescue HTTP::Error => e
    byebug
    1+1
  end
end
