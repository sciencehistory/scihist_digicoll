# This specifies what dyno types (worker VMs) are set up for heroku

web: bundle exec puma -C config/heroku_puma.rb

worker: bundle exec resque-pool

special_worker: bundle exec resque-pool --config  config/resque-pool-special-worker.yml

# https://devcenter.heroku.com/articles/release-phase
release: bundle exec rake scihist:heroku:on_release
