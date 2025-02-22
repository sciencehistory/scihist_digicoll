require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports. Chagne to false to see production-style error page
  config.consider_all_requests_local = true

  # use custom error pages when consider_all_requests_local = false
  config.exceptions_app = self.routes

  # Enable/disable other caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
  end

  # But force Rails.cache to memory store if we're doing turnstile bot detection,
  if ScihistDigicoll::Env.lookup(:cf_turnstile_enabled)
    config.cache_store = :memory_store
  end

  # Only in dev or test, let us know if we are passing params that haven't
  # been permitted, cause we have complicated params easy to miss one.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # devise mailers require this set
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # using the default async (in process thread pool) queue adapter for dev,
  # but let's set the pool sizes please to avoid running out of db connections
  # if we create a lot of jobs.
  config.active_job.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new(
    min_threads: 1,
    max_threads: (ENV.fetch("RAILS_MAX_THREADS") { 5 }).to_i - 1
  )

  # use ActionMailer previews feature, with previews in our rspec folder.
  # https://guides.rubyonrails.org/action_mailer_basics.html#previewing-emails
  config.action_mailer.preview_paths = ["#{Rails.root}/spec/mailers/previews"]

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations
  # config.i18n.raise_on_missing_translations = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # in development, allow the app to respond to our legacy oral history
  # hostname, by default oh.sciencehistory.org. You might use /etc/hosts
  # locally to test our legacy redirect functionality.
  config.hosts << ScihistDigicoll::Env.lookup!(:oral_history_legacy_host)
  # for browserstack local
  config.hosts << "bs-local.com"
end
