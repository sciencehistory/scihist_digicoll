# Helper for standard Cloudflare Turnstile on forms -- distinct from our bot_challenge_page
# page detection, this is used when we use Turnstile in the more conventional way,
# to guard a form submit.
#
# We do use turnstile keys from bot_challenge_page.
#
# This works with turnstile_form_protection.js , to invoke client-side turnstile,
# based on seeing the content rendered by `turnstile_form_protection` partial on
# the page.
#
# The logic here decides turnstile is unnecessary if it's told bot_challenge_page
# has already been passed.
#
# @example
#
# @turnstile_form_protection ||= TurnstileFormProtection.new(
#      token: params["cf-turnstile-response"],
#      remote_ip: request.remote_ip,
#      bot_challenge_passed: BotChallengePage::BotChallengePageController._bot_detect_passed_good?(self)
#    )
#
class TurnstileFormProtection
  FAILED_MESSAGE = "We couldn't verify you're not a bot. Please complete the verification and submit again."

  # @param token [String] turnstile token submitted, usually from params["cf-turnstile-response"]
  # @param remote_ip [String] usually from request.remote_ip
  # @param bot_challenge_passed [Boolean] usually from BotChallengePage::BotChallengePageController._bot_detect_passed_good?(controller_instance)
  def initialize(token:, remote_ip:, bot_challenge_passed:)
    @token = token
    @remote_ip = remote_ip
    @bot_challenge_passed = bot_challenge_passed
  end

  # show the widget?
  def needed?
    config.enabled && !@bot_challenge_passed
  end

  # ok to process the submitted form?
  def passed?
    return @passed if defined?(@passed)

    @passed = !needed? || verify_token
  end

  def sitekey
    config.cf_turnstile_sitekey
  end

  private

  def verify_token
    return false if @token.blank?

    result = HTTP.timeout(config.cf_timeout).post(config.cf_turnstile_validation_url,
      json: { secret: config.cf_turnstile_secret_key, response: @token, remoteip: @remote_ip }
    ).parse

    Rails.logger.warn("#{self.class.name}: Turnstile failed (#{@remote_ip}): #{result}") unless result["success"]
    result["success"] == true
  rescue HTTP::Error, JSON::ParserError => e
    Rails.logger.warn("#{self.class.name}: Turnstile validation error (#{@remote_ip}): #{e}")
    false
  end

  def config
    BotChallengePage::BotChallengePageController.bot_challenge_config
  end
end
