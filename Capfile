# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'

# Include tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#   https://github.com/capistrano/passenger
#
# require 'capistrano/rvm'
# require 'capistrano/rbenv'
# require 'capistrano/chruby'
require 'capistrano/bundler'
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'
require 'capistrano/passenger'
require 'capistrano/maintenance'
require 'whenever/capistrano'
require 'slackistrano/capistrano'

# git is no longer the default
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git


require 'capistrano/honeybadger'

require 'capistrano/rake' # let us run rake tasks on remote hosts

# our custom EC2 autodiscover server definition module
require_relative "config/deploy/lib/cap_server_autodiscover"


# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }


