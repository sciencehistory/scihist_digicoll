source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby File.read(".ruby-version").chomp

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.1'
gem 'webpacker', '~> 3.5'

gem "blacklight", "~> 7.0"

# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 3.11'

# resque+redis being used for activejob, maybe later for Rails.cache
# resque-pool currently does not support resque 2.0 alas.
# https://github.com/nevans/resque-pool/issues/170
gem "resque", "~> 1.0"
gem "resque-pool"

gem 'honeybadger', '~> 4.0'

# Use SCSS for stylesheets
gem 'sassc-rails', '~> 2.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

gem 'bootstrap', '~> 4.3'
gem 'sprockets-rails', '>= 2.3.2' # bootstrap gem requirement

gem 'jquery-rails', "~> 4.3"

# temporary kithe indexing branch, for scihist_digicoll indexing branch, do not
# intend to merge to master like this.
gem 'kithe', git: "https://github.com/sciencehistory/kithe.git"

# temporary git master, we should get on an attr_json release once we're settled down
gem "attr_json", git: "https://github.com/jrochkind/attr_json" #path: "../attr_json"

gem 'simple_form', "~> 4.0"
gem "cocoon"

gem "browse-everything", "~> 1.0"
gem "shrine", "~> 2.0" #, path: "../shrine"
# shrine-compat endpoint to get uppy to direct upload to S3 with resumable multi-part upload
gem "uppy-s3_multipart"
gem "content_disposition"

# slack notifications on capistrano deploys
gem 'slackistrano', "~> 3.8"

gem "ransack", "~> 2.1"
gem "kaminari", "~> 1.0"
gem 'bootstrap4-kaminari-views'

gem 'devise', "~> 4.5" # user accounts and login
gem 'access-granted', "~> 1.0" # authorization

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'solr_wrapper', "~> 2.1"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'capistrano', '~> 3.8'
  gem 'capistrano-bundler', '~> 1.2'
  gem 'capistrano-passenger', '~> 0.2'
  gem 'capistrano-rails', '~> 1.2'
  gem 'capistrano-maintenance', '~> 1.0', require: false
  gem 'capistrano-rake', require: false

end

group :test do
  gem 'rspec-rails', '~> 3.8'
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of chromedriver to run system tests with Chrome
  gem 'webdrivers'
  gem 'capybara-screenshot'
  gem 'factory_bot_rails'
  gem "database_cleaner", "~> 1.7"
  gem "webmock", "~> 3.5"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]


##
# Added by blacklight. Not sure why rsolr isn't just a BL dependency.
  gem 'rsolr', '>= 1.0', '< 3'
  # gem 'popper_js' #popper shouldn't be needed, it's already a dep of BL 4. PR to BL?

  # Used only for autocomplete, which we aren't currently using. Let's see if
  # we can get away without it in the future? It is an unmaintained dependency. :(
  gem 'twitter-typeahead-rails', '0.11.1.pre.corejavascript'

  # We would like to avoid this, but presently it's in there.
  gem 'devise-guests', '~> 0.6'
# end BL generated
