#Using the aws-sdk to locate servers via the Role tag and deploy to them.
require 'aws-sdk-ec2'
require 'yaml'
require 'aws-sdk-core'

set :stage, :staging
set :rails_env, 'production'
set :ssh_user, "digcol"

# cap variables used for AWS EC2 server autodiscover
  set :server_autodiscover_application, "scihist_digicoll"
  # We have things tagged in EC2 using 'staging' or 'production' the same values
  # we use for capistrano stage.
  set :server_autodiscover_service_level, fetch(:stage)

credentials_path = './cap_aws_credentials.yml'
#Checking for the needed credential file, which should overwrite any other ENV or file settings.
unless File.file?(credentials_path)
  puts "AWS credential file #{credentials_path} is missing. Please add it, with keys AccessKeyId and SecretAccessKey, for the `capistrano_deploy` AWS user."
  exit
end
aws_credentials = YAML.load_file(credentials_path)

# need to set AWS credentials before doing anything else, or AWS will lookup credentials from other
# default locations.
Aws.config[:credentials] = Aws::Credentials.new(aws_credentials['AccessKeyId'],aws_credentials['SecretAccessKey'])
ec2 = Aws::EC2::Resource.new(region: (aws_credentials["Region"] || "us-east-1"))

# The instance-state-code of 16 is a value from Amazon's docs for a running server.
# See: https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html
#
# We look for all servers with that state-code, and tags saying they are in the
# current application group, at the current service level (staging, production, etc).
# We will be deploying to those servers.
aws_instances = ec2.instances({
  filters: [
    {name:'instance-state-code', values:["16"]},
    {name: 'tag:Application', values: [fetch(:server_autodiscover_application)]},
    {name: 'tag:Service_level', values: [fetch(:server_autodiscover_service_level)]}
  ]
})

if aws_instances.count == 0
   puts "\n\nWARNING: Can not find any deploy servers via AWS lookup from tags! Will not deploy to servers!\n\n"
end

puts "Fetching servers from AWS EC2 tag lookup, from servers with tag:Application=#{fetch(:server_autodiscover_application)}...\n\n"
aws_instances.each do |aws_server|
  # Our servers in EC2 should have a "tag" with key "Capistrano_roles", that includes a
  # comma-separated lis to of capistrano roles to target that server.
  capistrano_roles = aws_server.tags.find {|tag| tag["key"]=="Capistrano_roles"}.value.split(",")

  server aws_server.public_ip_address, user: fetch(:ssh_user), roles: capistrano_roles
  puts "  server '#{aws_server.public_ip_address}', roles: #{capistrano_roles.collect(&:to_sym).collect(&:inspect).join(", ")}"
end

puts "\n"


# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server 'example.com', user: 'deploy', roles: %w{app db web}, my_property: :my_value
# server 'example.com', user: 'deploy', roles: %w{app web}, other_property: :other_value
# server 'db.example.com', user: 'deploy', roles: %w{db}



# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any  hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

# role :app, %w{deploy@example.com}, my_property: :my_value
# role :web, %w{user1@primary.com user2@additional.com}, other_property: :other_value
# role :db,  %w{deploy@example.com}



# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.



# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# The server-based syntax can be used to override options:
# ------------------------------------
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
