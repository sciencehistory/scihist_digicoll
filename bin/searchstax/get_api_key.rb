#!/usr/bin/env ruby
#
# A simple hacky script to get an API key suitable for use with certain SearchStax API
# actions. We use the API key to be able to push our solr configs to searcchstax



require 'io/console'
require 'json'
require 'shellwords'
require 'http'

# Hard-code this or ask for it?
account_name = "0XJ22VRJRE"

# Get a SearchStax API token, which is different than an "API key" -- tokens
# only last 24 hours -- but which we need in order to get an API key.
#
# https://www.searchstax.com/docs/staxapi2/#token

$stdout.print "Searchstax Username: "
username = $stdin.gets.chomp

$stdout.print "Password: "
password = $stdin.noecho(&:gets).chomp
puts

# eg `ss986903`
$stdout.print "Searchstax Deployment UID: "
searchstax_deployment_uid = $stdin.gets.chomp
puts
puts

# we're going to be lazy and just shell out to curl using template
# from SearchStax docs.


http_response = HTTP.
  headers("Content-Type" => "application/json").
  post("https://app.searchstax.com/api/rest/v2/obtain-auth-token/",
        json: { "username" => username, "password" => password})

json_response = http_response.body.to_s
parsed_response = JSON.parse(json_response)

unless http_response.status.success? && parsed_response["token"] && !parsed_response["token"].empty?
  $stderr.puts "Could not get token from SearchStax: #{http_response.code} #{json_response}"
  exit 1
end


# Now we need to use token to get a non-expiring API key
#
# https://www.searchstax.com/docs/staxapi2/#key


token = parsed_response["token"]

$stderr.puts "Token acquired: #{token}"

post_body = JSON.dump({ "scope" => ["deployment.dedicateddeployment"] })

http_response = HTTP.
  headers("Content-Type" => "application/json", "Authorization" => "Token #{token}").
  post("https://app.searchstax.com/api/rest/v2/account/#{account_name}/apikey/",
       json: {"scope" => ["deployment.dedicateddeployment"]})


json_response = http_response.body.to_s
parsed_response = JSON.parse(json_response)

unless http_response.status.success? && parsed_response["apikey"] && !parsed_response["apikey"].empty?
  $stderr.puts "Could not get apikey from SearchStax: #{http_response.code} #{json_response}"
  exit 1
end

api_key = parsed_response["apikey"]
$stderr.puts "apikey:\n\n"
$stdout.puts api_key

$stderr.puts "\n\nAssociating with deployment..."

# Now we need to associate that apikey with a deployment, phew!
#
# https://www.searchstax.com/docs/staxapi2/#addkeytodeployment


http_response = HTTP.
  headers("Content-Type" => "application/json", "Authorization" => "Token #{token}").
  post("https://app.searchstax.com/api/rest/v2/account/#{account_name}/apikey/associate/",
       json: {
        "apikey" => api_key,
        "deployment" => searchstax_deployment_uid
       })


json_response = http_response.body.to_s
parsed_response = JSON.parse(json_response)

unless http_response.status.success? && parsed_response["deployments"].is_a?(Array) && parsed_response["deployments"].include?(searchstax_deployment_id)
  $stderr.puts "Could not associate apikey with deployment: #{http_response.code} #{json_response}"
  exit 1
end

puts "Associated apikey with deployment UID #{searchstax_deployment_id}"
