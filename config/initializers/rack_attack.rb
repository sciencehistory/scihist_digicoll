# We need a cache, in development/test, by default cache to
# local memory store, unless you set
#
# In production, that won't really work if we have
# more than one puma worker, so we use a heroku memcached.

if Rails.env.development?
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
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


# And we want to log all rack-attack related notifications...
ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
  rack_request = payload[:request]
  rack_env     = rack_request.env

  Rails.logger.warn("rack_attack: #{name}: #{env["rack.attack.matched"]}: key=#{env["rack.attack.match_discriminator"]} request_id=#{request_id}  start=#{start.iso8601} finish=#{finish.iso8601}")
end
