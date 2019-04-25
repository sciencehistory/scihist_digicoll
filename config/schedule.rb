# Config file for `whenever, we use with capistrano to add/update/remove cronjobs
# on deploy servers with capistrano deploys.
# http://github.com/javan/whenever

env :PATH, ENV['PATH']

# Make sure honeybadger reports errors in crontab'd rake tasks.
env :HONEYBADGER_EXCEPTIONS_RESCUE_RAKE, true

# every :day, at: '2:00am', roles: [:cron] do
#   # just for testing, not really gonna do this, although we could
#   rake "scihist:solr:reindex"
# end
