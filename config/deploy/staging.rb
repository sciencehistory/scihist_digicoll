#Using the aws-sdk to locate servers via the Role tag and deploy to them.
require 'aws-sdk-ec2'
require 'yaml'
require 'aws-sdk-core'
set :stage, :staging
set :rails_env, 'production'
secret_location = './aws_secrets.yml'
server_roles = {"kithe"=>[':web', ':app', ':db', ':jobs', ':solr', ':cron']}
aws_region = "us-east-1"
service_level = "stage"
#Everything below here should be able to be turned into a method, the variables above may change based on server setup.
credential_file = File.file?(secret_location)
#Checking for the needed credential file, which should overwrite any other ENV or file settings.
if credential_file && true
#Edit ec2 for region changes, right now we only use one region. Also needs to come after the credential steps otherwise [default] aws credentials in the .aws directory may be used if present leading to erratic behavior.
  creds= YAML.load_file(secret_location)
  Aws.config[:credentials] = Aws::Credentials.new(creds['AccessKeyId'],creds['SecretAccessKey'])
  ec2 = Aws::EC2::Resource.new(region:"#{aws_region}")
#Server role keys should be the Role tag (assigned by ansible) that you want to deploy to. The array value is the list of capistrano roles that the server needs.
  server_roles.each do |key, value|
#Service level is set manually here, maybe make it a variable further up to be easy to spot when making new stages? 
#The instance-state-code of 16 is a value from Amazon's docs for a running server. See: https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html
    ec2.instances({filters: [{name:'instance-state-code', values:["16"]},{name: 'tag:Role', values: ["#{key}"]},{name: 'tag:Service_level', values: ["#{service_level}"]}]}).each do |ip|
#Deploy user is manually set here, see above comment about making it a variable.
      server "#{ip.public_ip_address}", user: 'digcol', roles: "#{value}"
    end
  end
else
  puts "AWS credential file aws_secrets.json is missing. Please add it to the base directory of the project."
  exit
end


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
