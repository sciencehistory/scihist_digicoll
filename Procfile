# This specifies what dyno types (worker VMs) are set up for heroku

web: bundle exec puma -C config/heroku_puma.rb

worker: bundle exec resque-pool

# special_worker dynos are used for occasional heavy lifting (e.g. generating derivatives en masse).
# To keep this work apart from the regular functioning of the application:
#     1. special_worker dynos will ONLY  execute jobs from the special_jobs queue.
#     2. Regular worker dynos will NEVER execute jobs from the special_jobs queue.
# See config/resque-pool-special-worker.yml for more details.
special_worker: bundle exec resque-pool --config  config/resque-pool-special-worker.yml
# A second one when we need two queues of special work!
special_worker_two: bundle exec resque-pool --config  config/resque-pool-special-worker-two.yml

# https://devcenter.heroku.com/articles/release-phase
release: bundle exec rake scihist:heroku:on_release
