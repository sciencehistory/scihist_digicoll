# This specifies what dyno types (worker VMs) are set up for heroku

web: bundle exec puma -C config/heroku_puma.rb

worker: bundle exec good_job start

# https://devcenter.heroku.com/articles/release-phase
release: bundle exec rake scihist:heroku:on_release
