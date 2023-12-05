# Heroku-recommende configuration from
# https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#config
#
# By default without setting heroku config this will create **1** puma processes, with 5 threads. (1
# worker is all that fits for our app in a small heroku dyno?)
# Setting heroku config vars can tune these.

# Barnes reports Ruby runtime metrics to Heroku, where we can monitor them.
# See https://devcenter.heroku.com/articles/language-runtime-metrics-ruby
require 'barnes'
before_fork do
  # worker specific setup
  Barnes.start # Must have enabled worker mode for this to block to be called
end


workers Integer(ENV['WEB_CONCURRENCY'] || 1)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

# https://github.com/puma/puma/blob/master/5.0-Upgrade.md
fork_worker

preload_app!

rackup      DefaultRackup if defined?(DefaultRackup)
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'


