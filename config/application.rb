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

    if ScihistDigicoll::Env.lookup("rails_log_level")
      config.log_level = ScihistDigicoll::Env.lookup("rails_log_level")
    end

    # Initialize configuration defaults for originally generated Rails version,
    # or Rails version we have upgraded to and verified for new defaults.
    config.load_defaults 6.1

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

    # Default 65K limit was getting in the way of large ingests.
    #
    # https://github.com/sciencehistory/scihist_digicoll/issues/888
    #
    # We don't believe this limit actually does anything useful anyway,
    # should be fine to set it to something absurdly large, we'll go with 10 megs
    #
    # https://github.com/rack/rack/pull/1487
    Rack::Utils.key_space_limit = 10.megabytes.to_i
  end
end
