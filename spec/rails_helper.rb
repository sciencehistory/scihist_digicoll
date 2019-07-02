# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

require 'capybara/rspec'
require 'capybara/rails'

require 'scihist_digicoll/solr_wrapper_util'


# get puma logs out of console
# https://github.com/rspec/rspec-rails/issues/1897
#Capybara.server = :puma, { Silent: true }
#
# When running tests, jrochkind is getting a core dump when using puma.
# Think it has to do with rspec setup of puma to use multiple workers,
# which is running into a bug. For now, we test with webrick, should be
# just fine.
Capybara.server = :webrick


# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"


  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true


  # eg `SHOW_BROWSER=true ./bin/rspec` will show you an actual chrome browser
  # being operated by capybara.
  $capybara_js_driver = ENV['SHOW_BROWSER'] ? :selenium_chrome : :selenium_chrome_headless

  # Capyabara.javascript_driver setting directly applies to 'feature' spec
  Capybara.default_driver = :rack_test # Faster but doesn't do Javascript
  Capybara.javascript_driver = $capybara_js_driver

  # and this applies to wrapped Rails 'system' tests, which rspec recommends
  # we use now over feature tests.
  #
  # https://medium.com/table-xi/a-quick-guide-to-rails-system-tests-in-rspec-b6e9e8a8b5f6
  # https://github.com/rspec/rspec-rails#system-specs-feature-specs-request-specswhats-the-difference
  # http://rspec.info/blog/2017/10/rspec-3-7-has-been-released/#rails-actiondispatchsystemtest-integration-system-specs
  #
  # We'll follow Rails system test's lead and make ALL system tests operate in a browser with JS,
  # No need for js: true. Meh, we'll let js: false override though.
  config.before(:each, type: :system) do
    driven_by $capybara_js_driver
  end
  config.before(:each, type: :system, js: false) do
    driven_by :rack_test
  end

  # tag your context or text with :logged_in_user, and we'll use devise to
  # do so. tag with `logged_in_user: :admin`, and it'll be an admin user.
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :integration
  config.before(:each, :logged_in_user) do |example|
    if example.metadata[:logged_in_user] == :admin
      sign_in FactoryBot.create(:admin_user)
    else
      sign_in FactoryBot.create(:user)
    end
  end

  # Get current_user to work in decorator (draper) specs when there is no logged in user,
  # where #current_user should be nil. Weird workaround with Draper.
  # https://github.com/drapergem/draper/issues/857
  config.before(:each, type: :decorator) do |example|
    unless example.metadata[:logged_in_user]
      _stub_current_scope :user, nil
    end
  end

  # Let blocks or tests add (eg) `queue_adapter: :test` to determine Rails
  # ActiveJob queue adapter. :test, :inline:, or :async, presumably.
  # eg `it "does something", queue_adapter: :inline`, or
  # `describe "something", queue_adapter: :inline`
  config.around(:example, :queue_adapter) do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = example.metadata[:queue_adapter]

    example.run

    ActiveJob::Base.queue_adapter = original
  end


  # disable Kithe::Indexable auto callbacks in our tests, they can be re-enabled in
  # certain tests with indexable_callbacks:true rspec metadata, implemented below.
  config.before(:suite) do
    Kithe.indexable_settings.disable_callbacks = true
  end

  # If you do want kithe auto-callbacks, for instance in many integration tests,
  # set indexable_callbacks:true in your rspec context/example metadata.
  #
  #    describe "something", indexable_callbacks: true do
  config.around(:each, :indexable_callbacks) do |example|
    original = Kithe.indexable_settings.disable_callbacks
    Kithe.indexable_settings.disable_callbacks = !example.metadata[:indexable_callbacks]
    example.run
    Kithe.indexable_settings.disable_callbacks = original
  end

  # Vaguely based on advice for sunspot-solr
  # https://github.com/sunspot/sunspot/wiki/RSpec-and-Sunspot#running-sunspot-during-testing
  #
  $test_solr_started = false
  config.before(:each, :solr) do
    unless $test_solr_started
      begin
        $stdout.write("(starting test solr)")

        at_exit {
          puts "Shutting down test solr..."
          ScihistDigicoll::SolrWrapperUtil.stop_with_collection(SolrWrapper.instance)
          $test_solr_started = false
        }

        WebMock.allow_net_connect!
        ScihistDigicoll::SolrWrapperUtil.start_with_collection(SolrWrapper.instance)

        $test_solr_started = true

      ensure
        ScihistDigicoll::SpecUtil.disable_net_connect!
      end
    end
  end
  config.after(:each, :solr) do
    Kithe::SolrUtil.delete_all(commit: :soft)
  end

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include FactoryBot::Syntax::Methods

  # In general we don't need database cleaner with Rails support for
  # transactions in tests, that now works even for browser tests.
  # But let's make sure the db is clean at beginning of test run.
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

end
