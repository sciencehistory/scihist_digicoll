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

    config.before_configuration do
      # We have some local classes in ./lib/, not autoloaded. We want them to be
      # available to our app code, so we require them here in a before_configuration
      # block, which works to make them available to rails app from early in boot.

      # In ./lib because we need to reference them in boot process where auto-loaded classes
      # shouldn't be accessed:
      require 'scihist_digicoll/env'

      # In ./lib because we need non-rails code, whenever crontab, to be able to get to it.
      require 'scihist_digicoll/asset_check_whenever_cron_time'
    end

    # Initialize configuration defaults for originally generated Rails version,
    # or Rails version we have upgraded to and verified for new defaults.
    config.load_defaults 6.0

    config.time_zone = "US/Eastern"

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

    # Show the GDPR "I accept" cookies banner by default.
    # This setting is overridden in test.rb,
    # so the tests don't have to click "I accept".)
    config.hide_accept_cookies_banner = false


  end
end
