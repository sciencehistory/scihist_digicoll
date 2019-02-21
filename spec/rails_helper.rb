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


# get puma logs out of console
# https://github.com/rspec/rspec-rails/issues/1897
Capybara.server = :puma, { Silent: true }

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
  # do so
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :integration
  config.before(:each, :logged_in_user) do
    sign_in FactoryBot.create(:user)
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
