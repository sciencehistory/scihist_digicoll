source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Include just the major/minor version of whatever we find in .ruby-version,
# ie `~> 2.5` or `~> 2.6`, not including additional that may be in 2.3
ruby "~> #{File.read(File.join(__dir__ , '.ruby-version')).chomp.split('.').slice(0,3).join('.')}"


gem 'lockbox'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.1'
gem 'webpacker', '~> 5.0'


#  Scout is a monitoring tool we are experimenting with
gem 'scout_apm'

# lock blacklight to current MINOR version. While BL minor version releases
# are theoretically backwards compat, experience shows they often cause problems.
# So you need to manually change this spec to allow updates when you want
# to spend the time to update Blacklight to latest -- you will usually want to update
# blacklight_range_limit to latest at same time.
gem "blacklight", "~> 7.7.0"
gem "blacklight_range_limit", "~> 7.0" # version sync'd with blacklight

gem "draper", "~> 4.0", ">= 4.0.1" # "decorators", which we use as view models

# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 5.3'

# resque+redis being used for activejob, maybe later for Rails.cache
# resque-pool currently does not support resque 2.0 alas.
# https://github.com/nevans/resque-pool/issues/170
gem "resque", "~> 2.0"
gem "resque-pool"
gem "resque-heroku-signals" # gah, weirdly needed for graceful shutdown on heroku. https://github.com/resque/resque#heroku

gem 'honeybadger', '~> 4.0'

# Until we get things working under sprockets 4, lock to sprockets 3
# https://github.com/sciencehistory/scihist_digicoll/issues/458
gem "sprockets", "~> 4.0"

# Use SCSS for stylesheets
gem 'sassc-rails', '~> 2.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
#gem 'coffee-rails', '~> 5.0'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

gem 'bootstrap', '~> 4.3'
gem 'sprockets-rails', '>= 2.3.2' # bootstrap gem requirement

gem 'jquery-rails', "~> 4.3"

gem 'font-awesome-rails', '~> 4.7'

# temporary kithe indexing branch, for scihist_digicoll indexing branch, do not
# intend to merge to master like this.
gem 'kithe', "~> 2.0", ">= 2.0.2"
# attr_son is a dependency of kithe, but we want to make sure it gets require'd directly
# to avoid weird auto-loading issues.
gem "attr_json", "~> 1.0"
gem "traject", ">= 3.5" # to include support for HTTP basic auth in Solr url

gem 'simple_form', "~> 5.0"
gem "cocoon"

gem "browse-everything", "~> 1.0"
gem "qa", "~> 5.2"
gem "shrine", "~> 3.3" #, path: "../shrine"
# shrine-compat endpoint to get uppy to direct upload to S3 with resumable multi-part upload
gem "uppy-s3_multipart"
gem "content_disposition", "~> 1.0"

gem 'faster_s3_url', "< 2" # for generating s3 urls faster!

# slack notifications on capistrano deploys
gem 'slackistrano', "~> 4.0"
gem "whenever" # automatic crontob maintenance, on capistrano deploys

gem "ransack", "~> 2.1"
gem "kaminari", "~> 1.2"
gem 'bootstrap4-kaminari-views'

gem 'devise', "~> 4.5" # user accounts and login
gem 'access-granted', "~> 1.0" # authorization

# decorating and truncating html
gem "rails_autolink", '~> 1.0'
gem 'html_aware_truncation', '~> 1.0'

gem "prawn", "~> 2.2" # creating PDFs
gem "pdf-reader", "~> 2.2" # simple metadata extraction from pdfs
gem 'rubyzip', '~> 2.0'
gem 'browser', '~> 5.0' # browser user-agent detection, maybe only for IE-unsupported warning.


# Until oai 1.0 is released...
gem 'oai', "~> 1.0", ">= 1.0.1"

gem 'sitemap_generator', '~> 6.0' # google sitemap generation

gem 'sane_patch', '< 2.0' # time-limited monkey patches

gem 'activerecord-postgres_enum', '~> 1.3' # can record postgres enums in schema.rb dump


# For autoscaling on heroku via hirefire.io service, but hopefully won't cause any problems
# when running not on heroku.
#
# https://help.hirefire.io/article/53-job-queue-ruby-on-rails
# https://help.hirefire.io/article/49-logplex-queue-time
# https://github.com/hirefire/hirefire-resource
gem "hirefire-resource"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'solr_wrapper', "~> 3.0", ">= 3.0.1"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'capistrano', '~> 3.8'
  gem 'capistrano-bundler', '~> 2.0', ">= 2.0.1"
  gem 'capistrano-passenger', '~> 0.2'
  gem 'capistrano-rails', '~> 1.2'
  gem 'capistrano-maintenance', '~> 1.0', require: false
end

group :test do
  gem 'rspec-rails', '~> 5.0'
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of chromedriver to run system tests with Chrome
  gem 'webdrivers'
  gem 'capybara-screenshot'
  gem 'factory_bot_rails'
  gem "database_cleaner", "~> 2.0"
  gem "webmock", "~> 3.5"
  gem "db-query-matchers", "< 2.0"
  # Used for Cap deployment to auto-lookup hosts from EC2 tags.
  gem 'aws-sdk-ec2', '>=1.74'

  gem 'rails-controller-testing'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# Not using any of these platforms, so commented out to avoid bundler warning.
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]




##
# Added by blacklight. Not sure why rsolr isn't just a BL dependency.
  gem 'rsolr', '>= 1.0', '< 3'
  # gem 'popper_js' #popper shouldn't be needed, it's already a dep of BL 4. PR to BL?

  # Used only for autocomplete, which we aren't currently using.
  # Twitter typehead is an unmaintained dependency, and if we wanted the func
  # we might consider reimplementing without it.
  # gem 'twitter-typeahead-rails', '0.11.1.pre.corejavascript'

  # If we aren't using bookmarks, we think we can avoid the devise-guests
  # gem and NOT having the #current_or_guest_user method that Blacklight uses
  # involving it. Seems not to be used if you don't use Bookmarks functionality.
  # gem 'devise-guests', '~> 0.6'
# end BL generated

# we use for data structures for citation models, and for generating citations
 gem "citeproc-ruby", '~> 1.0'
 gem 'csl-styles', '~> 1.0' # Need to load the styles so we can use chicago
