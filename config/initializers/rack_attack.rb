# We need a cache for throttling! Uses Rails.cache by default,
# which we set in config/application.rb. In development/test,
# may be in-memory cache, may have to toggle dev caching
# with `./bin/rails dev:cache`
if Rails.env.production? && (Rack::Attack.cache.nil? || Rack::Attack.cache.store.kind_of?(ActiveSupport::Cache::NullStore))
  # log with `rack_attack` token so our log watcher will catch it.
  Rails.logger.warn("rack_attack: rack-attack is not throttling, as we do not have a real Rails.cache available!")
end

# If any single client IP is making tons of requests, then they're
# probably malicious or a poorly-configured scraper. Either way, they
# don't deserve to hog all of the app server's CPU. Cut them off!
#
# Note: If you're serving assets through rack, those requests may be
# counted by rack-attack and this throttle may be activated too
# quickly. If so, enable the condition to exclude them from tracking.

# Throttle all requests by IP (60rpm)
#
# Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
#
# -------------------------
#
# Rack-attack docs suggested averaging one request per second over
# 5 minutes: limit: 300, period: 5.minutes
#
# But we're going to try a more generous 2 per second over
# 1 minute instead.
Rack::Attack.throttle('req/ip', limit: 120, period: 1.minutes) do |req|
  # On heroku, we may be delivering assets via rack, I think.
  req.ip unless req.path.start_with?('/assets')
end

# But we're also going to TRACK at somewhat lower limits, for ease
# of understanding what's going on in our logs
Rack::Attack.track("req_per_second_over_5_min", limit: 300, period: 5.minutes) do |req|
  req.ip unless req.path.start_with?('/assets')
end

# And we want to log all rack-attack related notifications... but only log once
# per rate-limit-application, don't keep logging every additional blocked request...
# kind of tricky to write logic to gate that.
ActiveSupport::Notifications.subscribe(/throttle\.rack_attack|track\.rack_attack/) do |name, start, finish, request_id, payload|
  rack_request = payload[:request]
  rack_env     = rack_request.env
  match_data   = rack_env["rack.attack.match_data"]
  match_data_formatted = match_data.slice(:count, :limit, :period).map { |k, v| "#{k}=#{v}"}.join(" ")

  period = match_data[:period] || 60.seconds
  match_name = rack_env["rack.attack.matched"]
  discriminator = rack_env["rack.attack.match_discriminator"]
  last_logged_key = "rack_attack_notification_#{name}_#{match_name}_#{discriminator}_count"

  last_logged_count = Rack::Attack.cache.read(last_logged_key)
  current_count = match_data[:count]

  # only log if we have a new count, not if we're still incrementing the count!
  if !last_logged_count || current_count <= last_logged_count
    # `name` will be throttle.rack_attack or track.rack_attack
    # `match_name` will be name of rule like 'req/ip'
    # `discriminator` will generally be IP address, or what you are grouping by to limit
    Rails.logger.warn("#{name}: #{match_name}: #{discriminator}: #{match_data_formatted} request_id=#{request_id}")
    Rack::Attack.cache.write(last_logged_key, current_count, period + 1)
  end
end
