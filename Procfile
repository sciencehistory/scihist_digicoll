# This specifies what dyno types (worker VMs) are set up for heroku

web: bundle exec puma -C config/heroku_puma.rb

worker: bundle exec resque-pool
