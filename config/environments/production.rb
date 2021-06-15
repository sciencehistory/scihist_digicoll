Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  # browse-everything currently delivers JS in ES6, so uglifier has to be able to
  # handle it. https://github.com/samvera/browse-everything/issues/257
  config.assets.js_compressor = Uglifier.new(harmony: true)
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  config.asset_host = ScihistDigicoll::Env.app_url_base_parsed.to_s

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ScihistDigicoll::Env.lookup!(:force_ssl) == "true"

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  config.active_job.queue_adapter     = :resque

  # We are not sharing a redis among multiple apps, seems no need to queue_name_prefix,
  # and it makes it confusing when trying to set resque workers to work specific
  # queues and getting it to match.
  config.active_job.queue_name_prefix = nil
  #config.active_job.queue_name_prefix = "scihist_digicoll_#{Rails.env}"

  # devise mailers require the `host` be set
  config.action_mailer.default_url_options = {
    host: ScihistDigicoll::Env.app_url_base_parsed.host,
    protocol: ScihistDigicoll::Env.app_url_base_parsed.scheme
  }

  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true

  # For images in emails:
  config.action_mailer.asset_host = ScihistDigicoll::Env.app_url_base_parsed.to_s


  # service_level can be either production, staging, or nil,
  # and ScihistDigicoll::Env enforces that it has to be
  # one of those three values.
  if ScihistDigicoll::Env.lookup(:service_level).nil?
    # It's fine to use a local sendmail setup
    # for development or testing.
    config.action_mailer.delivery_method = :sendmail
  else # production or staging environments
    if ScihistDigicoll::Env.lookup(:smtp_host).nil?
      raise RuntimeError, "Please specify smtp_host in local_env.py so we can send emails."
    end

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      :address => ScihistDigicoll::Env.lookup(:smtp_host),
      :port => 587,
      :user_name => ScihistDigicoll::Env.lookup(:smtp_username),
      :password =>  ScihistDigicoll::Env.lookup(:smtp_password),
      :authentication => :login,
      :enable_starttls_auto => true
    }
  end

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Turn off all action_view logging in production, to give us cleaner more readable
  # logs. Turns off lines such as:
  #     Rendering works/index.html.erb within layouts/application
  #     Rendered works/index.html.erb within layouts/application (2.0ms)
  #
  # https://stackoverflow.com/questions/12984984/how-to-prevent-rails-from-action-view-logging-in-production/61893582
  # https://github.com/projectblacklight/blacklight/issues/2379
  ActiveSupport::on_load :action_view do
    %w{render_template render_partial render_collection}.each do |event|
      ActiveSupport::Notifications.unsubscribe "#{event}.action_view"
    end
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

    # Inserts middleware to perform automatic connection switching.
    # The `database_selector` hash is used to pass options to the DatabaseSelector
    # middleware. The `delay` is used to determine how long to wait after a write
    # to send a subsequent read to the primary.
    #
    # The `database_resolver` class is used by the middleware to determine which
    # database is appropriate to use based on the time delay.
    #
    # The `database_resolver_context` class is used by the middleware to set
    # timestamps for the last write to the primary. The resolver uses the context
    # class timestamps to determine how long to wait before reading from the
    # replica.
    #
    # By default Rails will store a last write timestamp in the session. The
    # DatabaseSelector middleware is designed as such you can define your own
    # strategy for connection switching and pass that into the middleware through
    # these configuration options.
    # config.active_record.database_selector = { delay: 2.seconds }
    # config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
    # config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
end
