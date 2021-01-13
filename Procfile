# This specifies what dyno types (worker VMs) are set up for heroku

web: bundle exec puma -C config/heroku_puma.rb

worker: bundle exec resque-pool

# https://devcenter.heroku.com/articles/release-phase
release: bundle exec rake db:migrate scihist:solr_cloud:sync_configset
