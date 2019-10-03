require 'yajl'
require 'net/http'

namespace :scihist do
  desc '''
    # Checks the current metadata and checksums against a Fedora repository.
    # An example:
    export FEDORA_HOST_AND_PORT="http://35.173.191.206:8080"
    export FEDORA_USERNAME="joe"
    export FEDORA_PASSWORD="shmo"
    export RAILS_ENV="production"
    export METADATA_PATH="/tmp/fedora_export.json"
    curl -v \
            -H "Accept: application/ld+json"          \
            -u $FEDORA_USERNAME:$FEDORA_PASSWORD      \
            "$FEDORA_HOST_AND_PORT/fedora/rest/prod"  \
            -o $METADATA_PATH
    cd /opt/scihist_digicoll/current/
    bundle exec rake scihist:check_against_fedora
  '''

  task :check_against_fedora => :environment do
    file_path = 'fedora_export.json'
    fedora_host_and_port =  ENV['FEDORA_HOST_AND_PORT']
    fedora_username =       ENV['FEDORA_USERNAME']
    fedora_password =       ENV['FEDORA_PASSWORD']
    metadata_path   =       ENV['METADATA_PATH']
    percentage_to_check =   Integer(ENV['PERCENTAGE_TO_CHECK'] || "100")

    unless fedora_username &&
      fedora_password &&
      metadata_path &&
      fedora_host_and_port

      message = """Please supply:
        FEDORA_HOST_AND_PORT,
        FEDORA_USERNAME,
        FEDORA_PASSWORD, and
        METADATA_PATH
        via ENV variables."""
      abort (message)
    end
    options = {
      fedora_host_and_port: fedora_host_and_port,
      fedora_username:      fedora_username,
      fedora_password:      fedora_password,
      metadata_path:        metadata_path,
      percentage_to_check:  percentage_to_check
    }
    FedoraChecker.new(options: options).check
  end
end
