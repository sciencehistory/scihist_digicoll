Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Only in dev or test, let us know if we are passing params that haven't
  # been permitted, cause we have complicated params easy to miss one.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true


  # Hide the GDPR "I accept" cookies banner.
  config.hide_accept_cookies_banner = true


  # https://grosser.it/2017/04/29/rails-5-1-do-not-compile-asset-in-test-vs-asset-is-not-present-in-the-asset-pipeline/
  # make our tests fast by avoiding asset compilation
  # but do not raise when assets are not compiled either
  Rails.application.config.assets.compile = false
    Sprockets::Rails::Helper.prepend(Module.new do
      def resolve_asset_path(path, *)
        super || path
      end
    end)
  end
