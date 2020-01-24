# Config file for `whenever, we use with capistrano to add/update/remove cronjobs
# on deploy servers with capistrano deploys.
# http://github.com/javan/whenever

env :PATH, ENV['PATH']

# Make sure honeybadger reports errors in crontab'd rake tasks.
env :HONEYBADGER_EXCEPTIONS_RESCUE_RAKE, true

# every :day, at: '2:00 am', roles: [:cron] do
#   # just for testing, not really gonna do this, although we could
#   rake "scihist:solr:reindex"
# end

every :day, :at => '2:00 am', roles: [:cron] do
  rake "blacklight:delete_old_searches[7]"
end

every :tuesday, :at => '4:00 am', roles: [:cron] do
  rake "sitemap:create"
end


require File.expand_path(File.dirname(__FILE__) + "/../lib/scihist_digicoll/asset_check_whenever_cron_time")
every :day, :at => ScihistDigicoll::ASSET_CHECK_WHENEVER_CRON_TIME, roles: [:cron] do
  rake "scihist:check_fixity"
end

every :minute, roles: [:cron] do
  rake "scihist:check_fixity_simple"
end
