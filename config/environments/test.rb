require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Speed up tests a little bit by logging less
  config.active_record.verbose_query_logs = false
  config.active_record.query_log_tags_enabled = false
  config.log_level = :fatal

  # Use :test ActiveJob adapter which does not really run jobs, as default.
  # We can change on an example-by-example basis if needed.
  config.active_job.queue_adapter = :test

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # let's not use gzip compression of responses in test, just slows things down
  config.middleware.delete Rack::Deflater

  # Raise exceptions instead of rendering exception templates.
  # :rescueable is default in Rails 7.1, but we need to fix our tests
  config.action_dispatch.show_exceptions = :none

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.perform_caching = false

  config.action_mailer.default_url_options = {
    host: ScihistDigicoll::Env.app_url_base_parsed.host
  }

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise
  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Only in dev or test, let us know if we are passing params that haven't
  # been permitted, cause we have complicated params easy to miss one.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true
end
