#Using the aws-sdk to locate servers via the Role tag and deploy to them.
require 'aws-sdk-ec2'
require 'yaml'
require 'aws-sdk-core'

set :stage, :staging
set :rails_env, 'production'


# cap variables used for AWS EC2 server autodiscover
set :server_autodiscover_application, "scihist_digicoll"

credentials_path = './cap_aws_credentials.yml'
service_level = "staging"
#Everything below here should be able to be turned into a method, the variables above may change based on server setup.

#Checking for the needed credential file, which should overwrite any other ENV or file settings.
unless File.file?(credentials_path)
  puts "AWS credential file #{credentials_path} is missing. Please add it, with keys AccessKeyId and SecretAccessKey, for the `capistrano_deploy` AWS user."
  exit
end

#Edit ec2 for region changes, right now we only use one region. Also needs to come after the credential steps otherwise [default] aws credentials in the .aws directory may be used if present leading to erratic behavior.
creds= YAML.load_file(credentials_path)
Aws.config[:credentials] = Aws::Credentials.new(creds['AccessKeyId'],creds['SecretAccessKey'])

ec2 = Aws::EC2::Resource.new(region: (creds["Region"] || "us-east-1"))
#Server role keys should be the Role tag (assigned by ansible) that you want to deploy to. The array value is the list of capistrano roles that the server needs.

#Service level is set manually here, maybe make it a variable further up to be easy to spot when making new stages?
#The instance-state-code of 16 is a value from Amazon's docs for a running server. See: https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html
aws_instances = ec2.instances({
  filters: [
    {name:'instance-state-code', values:["16"]},
    {name: 'tag:Application', values: [fetch(:server_autodiscover_application)]},
    {name: 'tag:Service_level', values: [service_level]}
  ]
})

if aws_instances.count == 0
   puts "\n\nWARNING: Can not find any deploy servers via AWS lookup from tags! Will not deploy to servers!\n\n"
end

puts "Fetching servers from AWS EC2 tag lookup...\n\n"
aws_instances.each do |aws_server|
#Search across the tags and find the one labeled capistrano_roles, tags are hashes with 2 values, key for tag name and value for tag value.
  capistrano_tag = aws_server.tags.select{|tag| tag["key"]=="Capistrano_roles"}
#Turn the tag (via the value field in the hash) into an array
  capistrano_roles = capistrano_tag[0][:value].split(',')
#Deploy user is manually set here, see above comment about making it a variable.
  server aws_server.public_ip_address, user: 'digcol', roles: capistrano_roles

  puts "  server #{aws_server.public_ip_address}, roles: #{capistrano_roles.collect(&:to_sym).collect(&:inspect).join(", ")}"
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
