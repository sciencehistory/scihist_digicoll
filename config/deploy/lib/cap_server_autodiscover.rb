require 'aws-sdk-ec2'
require 'aws-sdk-core'
require 'yaml'
require 'pastel'

# A module mix-in to provide auto-discover of servers from EC2 tags, for capistrano.
#
# It's just a module mix-in, in a cap stage file like `deploy/staging.rb`, you just:
#
#    include CapServerAutodiscover
#    cap_server_autodiscover
#
# To provide AWS credentials, you must have a file in your app root called `cap_aws_credentials.yml`, that looks like:
#     AccessKeyId: [secret_key_id]
#     SecretAccessKey: [secret_access_key]
#     # optional, default is us-east-1:
#     Region: us-east-1
#
# This routine yses cap variables:
#
# * ssh_user: servers will be created with this value as `user`.
# * server_autodiscover_application: filter on EC2 tag:Application
# * server_autodiscover_service_level: filter on EC2 tag:Service_level (default capistrano fetch(:stage))
# * server_autodiscover_expected_roles: array of symbols, will warn to console if they aren't all found from autodiscovered servers
#
# This is installed in our cap by:
# * `Capfile` requires this file
# * deploy.rb `include`s the module, so it's method is available to stage files.
#
# We hadn't noticed there was an existing solution already written before writing this, for future
# reference we may want to consult:
#   https://github.com/fernandocarletti/capistrano-aws
# (athough it's missing some features we need, like filtering on `instance-state-code`)
module CapServerAutodiscover
  def cap_server_autodiscover
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
        {name: 'tag:Service_level', values: [fetch(:server_autodiscover_service_level)]},
        {name: 'tag-key', values:["Capistrano_roles"]}
      ]
    })

    roles_defined = Set.new

    puts "Fetching servers from AWS EC2 tag lookup, from servers with tag:Application='#{fetch(:server_autodiscover_application)}'   ...\n\n"
    aws_instances.each do |aws_server|
      # Our servers in EC2 should have a "tag" with key "Capistrano_roles", that includes a
      # comma-separated lis to of capistrano roles to target that server.
      capistrano_roles = aws_server.tags.find {|tag| tag["key"]=="Capistrano_roles"}.value.split(",")
      roles_defined += capistrano_roles

      server_name = aws_server.tags.find {|t| t["key"] == "Name" }.value

      server aws_server.public_ip_address, user: fetch(:ssh_user), roles: capistrano_roles
      puts "  server '#{aws_server.public_ip_address}', roles: #{capistrano_roles.collect(&:to_sym).collect(&:inspect).join(", ")} # name: #{server_name}"
    end

    puts "\n"

    missing_roles = fetch(:server_autodiscover_expected_roles).collect(&:to_s) - roles_defined.collect(&:to_s)
    unless missing_roles == []
       puts Pastel.new.red("WARNING: Autodiscovered servers not found for roles: #{missing_roles.join(", ")}; may be an incomplete deploy")
       puts "  => found servers for: #{roles_defined.empty? ? 'no roles' : roles_defined.join(', ')}\n\n"
    end
  end
end
