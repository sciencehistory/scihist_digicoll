# We need a cache for throttling! Uses Rails.cache by default,
# which we set in config/application.rb. In development/test,
# may be in-memory cache, may have to toggle dev caching
# with `./bin/rails dev:cache`
if Rails.env.production? && (Rack::Attack.cache.nil? || Rack::Attack.cache.store.kind_of?(ActiveSupport::Cache::NullStore))
  # log with `rack_attack` token so our log watcher will catch it.
  Rails.logger.warn("rack_attack: rack-attack is not throttling, as we do not have a real Rails.cache available!")
end

RACK_ATTACK_THROTTLE_EXEMPT_IPS = ScihistDigicoll::Env.lookup(:main_office_ips) || []

# If any single client IP is making tons of requests, then they're
# probably malicious or a poorly-configured scraper. Either way, they
# don't deserve to hog all of the app server's CPU. Cut them off!
#
# Note: If you're serving assets through rack, those requests may be
# counted by rack-attack and this throttle may be activated too
# quickly. If so, enable the condition to exclude them from tracking.

# Throttle all requests by IP
#
# Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
#
# -------------------------
#
# Rack-attack docs suggested averaging one request per second over
# 5 minutes: limit: 300, period: 5.minutes
#
# But we're going to try a more generous 3 per second over
# 1 minute instead.
#
Rack::Attack.throttle('req/ip', limit: 180, period: 1.minutes) do |req|
  # On heroku, we may be delivering assets via rack, I think.
  # We also try to exempt our "api" responses from rate limit, although
  # we still include them in tracking logging below.
  req.ip unless (
                  req.ip.in?(RACK_ATTACK_THROTTLE_EXEMPT_IPS) || # exempt 315 chestnut from this rate limit
                  req.path.start_with?('/assets') ||
                  req.path.end_with?(".atom") ||
                  req.path.end_with?(".xml") ||
                  req.path.end_with?(".json")
                 )
end

# And we want to log rack-attack track and throttle  notifications. But we get
# a notification every time an IP has exceeded the limit -- that's far too
# many to log every time, could be many per second when it's exceeding limits.
#
# We want to log once per period of our limits -- eg one minute, for records.
#
# But we want to ALERT us even less than that -- say once per day -- so we
# log a special log line with 'ALERT' in it even less frequently, that we
# can have papertrail set an alert for us on, on the string: `rack_attack: ALERT`.
# We also do reverse IP lookup on the less frequent ALERTS.
#
# To do this, we need to store and consult some state about the last time(s)
# we logged, which we do in the cache that rack-attackc is already using
# (probably the Rails.cache which is probably a memcached)
#
# The implementation of all of this is currently kind of squirrely and hard
# to follow, sorry.
alert_only_per = 1.day
ActiveSupport::Notifications.subscribe(/throttle\.rack_attack|track\.rack_attack/) do |name, start, finish, request_id, payload|
  rack_request = payload[:request]
  rack_env     = rack_request.env
  match_name = rack_env["rack.attack.matched"]

  # only log here for our `req/` throttle  above, not our other ones such as bot detect
  next unless match_name == "req/ip"

  match_data   = rack_env["rack.attack.match_data"]
  match_data_formatted = match_data.slice(:count, :limit, :period).map { |k, v| "#{k}=#{v}"}.join(" ")

  discriminator = rack_env["rack.attack.match_discriminator"] # generally the IP address
  last_logged_key = "rack_attack_notification_#{name}_#{match_name}_#{discriminator}"

  last_logged_info = Rack::Attack.cache.read(last_logged_key)
  # should be a serialized JSON hash
  last_logged_info = if last_logged_info.kind_of?(String)
    JSON.parse(last_logged_info) rescue JSON::ParserError
  else
    {}
  end


  last_logged_count = last_logged_info['count']
  last_alerted_time = last_logged_info['last_alerted_time'] && (Time.iso8601(last_logged_info['last_alerted_time']) rescue nil)
  current_count = match_data[:count]

  # only log if we have a new count, not if we're still incrementing the count!
  if !last_logged_count || current_count <= last_logged_count.to_i
    last_logged_info['count'] = current_count

    # if it's been longer than our alert window, we log a special ALERT
    # that papertrail can be configured to notify us on
    #
    # `name` will be throttle.rack_attack or track.rack_attack
    # `match_name` will be name of rule like 'req/ip'
    # `discriminator` will generally be IP address, or what you are grouping by to limit
    current_time = Time.now
    if !last_alerted_time || (current_time - last_alerted_time) > alert_only_per
      hostname = Resolv.getname(discriminator) rescue nil
      last_logged_info['last_alerted_time'] = current_time.utc.iso8601 # record time so we don't do it again soon
      # eg: track.rack_attack: ALERT: req/ip_track: 66.249.66.21 (crawl-66-249-66-21.googlebot.com) count=91 limit=90 period=60
      Rails.logger.warn("#{name}: ALERT: #{match_name}: #{discriminator} (#{hostname || "no hostname"}) #{match_data_formatted}")
    else
      # eg: track.rack_attack: req/ip_track: 66.249.66.21 count=91 limit=90 period=60
      Rails.logger.warn("#{name}: #{match_name}: #{discriminator}: #{match_data_formatted}")
    end

    # we put it in cache for up to our total alert window, so we can make sure
    # not to alert more than that.
    Rack::Attack.cache.write(last_logged_key, JSON.dump(last_logged_info), alert_only_per)
  end
end
