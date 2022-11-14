require 'scihist_digicoll/logger_formatter'

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

  # custom error pages
  # https://www.marcelofossrj.com/recipe/2019/04/14/custom-errors.html
  config.exceptions_app = self.routes

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
  if ScihistDigicoll::Env.lookup(:rails_asset_host).present?
    config.asset_host = ScihistDigicoll::Env.lookup(:rails_asset_host)
  end

  # CORS headers for fonts served on seperate asset_host
  config.public_file_server.headers = {
    # Difficult getting this to work properly, can't really support multiple specifically
    # allowed hostnames via the statis public_file_server.headers , and I don't think
    # actually necessary for any kind of security:
    #
    # 'Access-Control-Allow-Origin' => ScihistDigicoll::Env.lookup(:app_url_base).chomp('/'),
    # 'Vary' => "Origin",
    #
    # Instead we just:
    'Access-Control-Allow-Origin' => "*",
    'Cache-Control' => 'public, max-age=31536000' # 1 year, max accepted value. Assets are timestamped so cacheable forever.
  }

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ScihistDigicoll::Env.lookup(:force_ssl)

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  #
  # On heroku we use memcachedcloud plugin which provides `MEMCACHEDCLOUD_SERVERS`
  # env. https://devcenter.heroku.com/articles/memcachedcloud#using-memcached-from-ruby
  #
  # Caching is not normally turned on in test or dev, but config/environments/development.rb
  # has some standard Rails code that lets you turn it on in dev with in-memory store,
  # with `./bin/rails dev:cache` toggle.
  #
  # We tune the timeouts to give up really quickly -- we don't want the server
  # waiting too long on a slow memcached, especially with rack-attack accessing
  # it on every request. It's just a cache, give up if it's slow!
  # https://github.com/petergoldstein/dalli/blob/5588d98f79eb04a9abcaeeff3263e08f93468b30/lib/dalli/protocol/connection_manager.rb
  if ENV["MEMCACHEDCLOUD_SERVERS"]
    config.cache_store = :mem_cache_store, ENV["MEMCACHEDCLOUD_SERVERS"].split(','), {
      :username => ENV["MEMCACHEDCLOUD_USERNAME"],
      :password => ENV["MEMCACHEDCLOUD_PASSWORD"],
      :socket_timeout => 0.15, # default was 1
      :socket_failure_delay => false # don't retry failures
    }
  end


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
  #config.log_formatter = ::Logger::Formatter.new
  #
  # Use our custom logging formatter, that includes only log level and message,
  # not a bunch of things we don't need on heroku/paperclip.
  config.log_formatter = ScihistDigicoll::LoggerFormatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  # The RAILS_LOG_TO_STDOUT is generated by rails standardly, and used by heroku.
  # We add the RAILS_DISABLE_LOGGING to disable logs entirely, which we find useful
  # capturing output from a  `heroku run rake` task, where otherwise heroku
  # insists on combining stderr and stdout and we have to keep stdout clean
  # for our output.
  if ENV["RAILS_DISABLE_LOGGING"].present?
    config.logger    = ActiveSupport::Logger.new("/dev/null")
  elsif ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end


  # Actually use lograge instead https://github.com/roidrage/lograge

  config.lograge.enabled = true
  #
  # custom_payload is merged into log data automatically
  config.lograge.custom_payload do |controller|
    # default lograge in `path` would put just eg `/catalog`, we want the whole
    # URL in there eg `/catalog?q=foo`, so we override. Alternately, you could
    # of course add this as `fullpath` to have both.
    # https://bibwild.wordpress.com/2021/08/04/logging-uri-query-params-with-lograge/
    #
    # Also we include some user-agent info, but compressed with device_detector gem
    {
      path: controller.request.filtered_path,
      ua: CompactUserAgent.new(controller.request.user_agent).compact,
      # wasn't sure if we should use request.remote_ip or request.ip, the
      # difference is not clear, or what it seems, in docs or online info
      ip: controller.request.ip
    }
  end

  # This default Rails log config probably doesn't do anything if we're using
  # lograge anyway, but we leave it here in case we turn lograge off again,
  # it reduces default Rails logging significantly, eliminating things
  # we don't need.
  #
  # Turn off all action_view logging in production, to give us cleaner more readable
  # logs. Turns off lines such as:
  #     Rendering works/index.html.erb within layouts/application
  #     Rendered works/index.html.erb within layouts/application (2.0ms)
  #
  # https://stackoverflow.com/questions/12984984/how-to-prevent-rails-from-action-view-logging-in-production/61893582
  # https://github.com/projectblacklight/blacklight/issues/2379
  ActiveSupport::on_load :action_view do
    %w{render_template render_partial render_collection render_layout}.each do |event|
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
