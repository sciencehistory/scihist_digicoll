source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Heroku uses this: We want to allow latest PATCH version of ruby, such as
# "~> 3.2.2" would allow any 3.2.x >= than 3.2.2
#
# We take the number .ruby-version file, make sure we trim off any extraneous pre-release
# or other stuff on end, and create spec matching above.
ruby "~> #{File.read(File.join(__dir__ , '.ruby-version')).chomp.split('.').slice(0,3).join('.')}"


gem 'lockbox'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 8.0.0'

# note we use vite-ruby for css and JS, but propshaft delivers some static images and
# other static assets, as well as produced files from vite.
gem "propshaft", "~> 1.3"

# Ensure we are using rack 3, with a new sinatra that can use it. Both of these
# are indirect dependencies, in here only to force bundler NOT to do a weird
# resolution to old versions of sinatra!
# https://bibwild.wordpress.com/2023/11/09/beware-sinatra-rails-7-1-rack-3-resque-bundler-dependency-resolution/
gem "rack", ">= 3.0"
gem "sinatra", ">= 4.0"

# Our JS/CSS/asset bundler
# After updating, you always need to run `bundle exec vite upgrade` to update JS packages to match
# among other things.
gem "vite_rails", "~> 3.0"

# mail is a rails dependency, opt into 2.8.0.rc1 pre-release for ruby 3.1 compat,
# this line is no longer needed once 2.8.0 final is released:
gem "mail", ">= 2.8.0.rc1", "< 3"

# avoid buggy net-protocol 0.2.0 which causes some problems with shrine.
#
# See:
# * https://github.com/shrinerb/shrine/issues/609#issuecomment-1340133144
# * https://github.com/shrinerb/shrine/issues/610
#
gem "net-protocol", "!= 0.2.0"

gem "view_component", "~> 4.0"
gem "alba", "~> 3.1" # for JSON serialization of models
#  Scout is a monitoring tool we are experimenting with
gem 'scout_apm'

# lock blacklight to current MINOR version. While BL minor version releases
# are theoretically backwards compat, experience shows they often cause problems.
# So you need to manually change this spec to allow updates when you want
# to spend the time to update Blacklight to latest -- you will usually want to update
# blacklight_range_limit to latest at same time.
#
# NOTE ALSO: We are using `blacklight-frontend` JS NPM package, updating blacklight
# version may require an update with yarn to `blacklight-frontend`, has to be
# checked manually.
gem "blacklight", "~> 9.0.0.beta8"
gem "blacklight_range_limit", "~> 9.1.0" # version no longer sync'd with blacklight, not sure how we tell what version works with what version of BL

# for some code to deal with transcoding video, via AWS MediaConvert
# Lower than 1.2.1 had far too big gem builds! https://github.com/samvera-labs/active_encode/issues/126
gem "active_encode", "~> 2.0"

# these gems are needed for active_encode MediaConvert adapter
# https://github.com/samvera-labs/active_encode/blob/main/guides/media_convert_adapter.md
gem "aws-sdk-cloudwatchevents", "~> 1.0"
gem "aws-sdk-cloudwatchlogs", "~> 1.0"
gem "aws-sdk-mediaconvert", "~> 1.0"
gem "aws-sdk-s3", "~> 1.0"
gem "aws-sdk-cloudfront", "~> 1.91"

# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '>= 7.0.0.pre1', '< 8'

# resque+redis being used for activejob.
# resque-pool currently does not support resque 2.0 alas.
# https://github.com/nevans/resque-pool/issues/170
gem "resque", "~> 2.0"
gem "resque-pool"
gem "resque-heroku-signals" # gah, weirdly needed for graceful shutdown on heroku. https://github.com/resque/resque#heroku


gem "http", "~> 5.2" # for http client access

# using memcached for Rails.cache in production, requires dalli

gem 'honeybadger', '~> 6.0'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

gem 'font-awesome-rails', '~> 4.7'

gem "lograge", "< 2"
gem "device_detector", "~> 1.0" # user-agent parsing we use for logging

gem "attr_json", "~> 2.3"

gem 'kithe', "~> 2.17"

gem "traject", ">= 3.5" # to include support for HTTP basic auth in Solr url

gem 'simple_form', "~> 5.0"

gem "browse-everything", ">= 2.0.0.alpha.1", "< 3"
gem "qa", "~> 5.2", ">= 5.14.0"
gem "shrine", "~> 3.3" #, path: "../shrine"
# shrine-compat endpoint to get uppy to direct upload to S3 with resumable multi-part upload
gem "uppy-s3_multipart"
gem "content_disposition", "~> 1.0"

gem 'faster_s3_url', "~> 1.1" # for generating s3 urls faster!

gem "kaminari", "~> 1.2"
gem 'bootstrap4-kaminari-views'

gem 'devise', "~> 4.5" # user accounts and login
gem 'access-granted', "~> 1.0" # authorization
gem 'omniauth-entra-id'
gem 'omniauth-rails_csrf_protection'


# decorating and truncating html
gem "rinku", '~> 2.0' # auto-linking
gem 'html_aware_truncation', '~> 1.0'

gem "prawn", "~> 2.2" # creating PDFs
gem "prawn-svg", "< 2"
gem "prawn-html", "< 2"
# The prawn gem uses `matrix`; as of ruby 3.1 it needs to be declared explicitly.
# There isn't a prawn release that does that yet, although it's been
# fixed in prawn master. We can work around that by adding an explicit top-level dependency.
#
# https://github.com/prawnpdf/prawn/issues/1235
# https://github.com/prawnpdf/prawn/commit/3658d5125c3b20eb11484c3b039ca6b89dc7d1b7
gem 'matrix', '~> 0.4'

gem "pdf-reader", "~> 2.2" # simple metadata extraction from pdfs
gem 'rubyzip', '~> 3.0'
gem 'browser', '~> 6.0' # browser user-agent detection, maybe only for IE-unsupported warning.


# Until oai 1.0 is released...
gem 'oai', "~> 1.0", ">= 1.0.1"

gem 'sitemap_generator', '~> 6.0' # google sitemap generation

gem 'sane_patch', '< 2.0' # time-limited monkey patches

gem 'activerecord-postgres_enum', '~> 2.0' # can record postgres enums in schema.rb dump


# For autoscaling on heroku via hirefire.io service, but hopefully won't cause any problems
# when running not on heroku.
#
# https://help.hirefire.io/article/53-job-queue-ruby-on-rails
# https://help.hirefire.io/article/49-logplex-queue-time
# https://github.com/hirefire/hirefire-resource
gem "hirefire-resource", ">= 0.10.1"

# Speed up pasting into irb/console by using newer bugfixed
# dependencies!
# https://github.com/ruby/irb/issues/43#issuecomment-758089211
gem "irb", ">= 1.3.1"
gem "reline", ">= 0.2.1"
gem "warning", "~> 1.2" # managing ruby warning output

gem "rack-attack", "~> 6.6" # throttling excessive requests

gem "webvtt-ruby", "< 2" # https://github.com/opencoconut/webvtt-ruby

# MS Word .docx for some OH transcript handling
gem "docx", "< 1.0"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'solr_wrapper', "~> 4.0"
  # gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  gem 'listen', '~> 3.3'
end

# rspec-rails is NOt in group :test, so we can run `rspec system_env_spec` on heroku,
# where dev/test aren't installed.
gem 'rspec-rails', '~> 8.0'

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of chromedriver to run system tests with Chrome
  #gem 'webdrivers'
  gem 'capybara-screenshot'
  gem 'factory_bot_rails'
  gem "database_cleaner", "~> 2.0"
  gem "webmock", "~> 3.5"
  gem "db-query-matchers", "< 2.0"
  gem 'rails-controller-testing'
  gem 'axe-core-rspec', "~> 4.3" # accessibilty testing
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# Not using any of these platforms, so commented out to avoid bundler warning.
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]




##
# Added by blacklight. Not sure why rsolr isn't just a BL dependency.
  # We need RSolr 2.x to get faraday-based connection so we can customize
  # middleware, so we customize dependency to require 2.x
  gem 'rsolr', '~> 2.4'
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
 gem "citeproc-ruby", '~> 2.0'
 # We vendor specific files from csl-styles now,
 # See vendor/citation-style-language/README.md
 #gem 'csl-styles', '~> 2.0' # Need to load the styles so we can use chicago

 gem 'ruby-progressbar'

# faraday is a transitive dependency, but we interact with it directly
# to configure Blacklight, for automatic retry
 gem "faraday", "~> 2.0"
 gem "faraday-retry", "~> 2.0"

 gem "csv", "~> 3.3.0"


# Barnes reports Ruby runtime metrics to Heroku, where we can monitor them.
# See https://devcenter.heroku.com/articles/language-runtime-metrics-ruby
gem "barnes"

gem 'equivalent-xml'

# temporary new bot challenge page
gem "bot_challenge_page", ">= 0.10.0", "< 2"

gem "ruby-openai", "~> 8.0"
