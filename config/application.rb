require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
require "rails/test_unit/railtie"


# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ScihistDigicoll
  class Application < Rails::Application
    # We have some local classes in ./lib/, not autoloaded. We want them to be
    # available to our app code, so we require them here in a before_configuration
    # block, which works to make them available to rails app from early in boot.
    # Because of Rails peculiarities, these need to happen inside class body, not
    # at top of file.

    # In ./lib because we need to reference them in boot process where auto-loaded classes
    # shouldn't be accessed:
    require 'scihist_digicoll/env'

    # Enables YJIT as of Ruby 3.3, to bring sizeable performance improvements. If you are
    # deploying to a memory constrained environment you may want to set this to `false`.

    # scihist: on heroku that are NOT web workers (bg workers, console), we are currently
    # memory constrained, and also don't need this performance, so disable.  Dyno type
    # is available from Heroku $DYNO. https://devcenter.heroku.com/articles/dynos#local-environment-variables
    if ENV['DYNO'].present? && ! ENV['DYNO'].start_with?("web.")
      Rails.application.config.yjit = false
    else
      Rails.application.config.yjit = true
    end

    if ScihistDigicoll::Env.lookup("rails_log_level")
      config.log_level = ScihistDigicoll::Env.lookup("rails_log_level")
    end

    # lograge config. lograge is turned on in production.rb with
    # config.lograge.enabled = true
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
        ip: controller.request.ip,
        bot_chlng: controller.request.env["bot_detect.blocked_for_challenge"]
      }.compact
    end

    config.lograge.ignore_custom = lambda do |event|
      # omit logging of bot-challenged requests, there are too many, filling up
      # our papertrail account. We still store them in db BotChallengedRequest
      event.payload[:request].env["bot_detect.should_challenge"]
    end

    # Initialize configuration defaults for originally generated Rails version,
    # or Rails version we have upgraded to and verified for new defaults.
    config.load_defaults 8.0

    config.time_zone = ENV['TZ'].presence || "America/New_York"

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    #
    config.generators do |g|
      g.assets            false
      g.helper            false
      g.javascript        false
      g.stylesheets       false
      g.stylesheets_engine :scss
      g.test_framework    :rspec, fixtures: false, view_specs: false, helper_specs: false, routing_specs: false
      #generate.fixture_replacement :factory_bot, dir: "spec/factories"
      g.jbuilder          false
    end

    # code to be executed when launching `rails console`
    # https://github.com/rails/rails/blob/cf27cfa18bc3742cfaf732da5a839521d6662785/railties/lib/rails/railtie.rb#L143

require 'rack/attack'
    console do
      # Disable honeybadger reporting in conosle. Avoid those annoying SIGHUP errors
      # reported for timed out console you left running.
      Honeybadger.configure do |config|
        config.report_data = false
      end
    end

    ###
    # Local custom scihist config
    ###

    # Organizational social media accounts/handles
    config.twitter_acct = "scihistoryorg"
    config.facebook_acct = "SciHistoryOrg"
    config.instagram_acct = "scihistoryorg"
  end
end
