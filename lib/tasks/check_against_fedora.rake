require 'yajl'
require 'net/http'
#require 'app/services/fedora_checker'

namespace :scihist do
  desc """
    Checks the current metadata and checksums against a Fedora repository.
    bundle exec rake scihist:check_against_fedora
  """

  # Print the top-level contents of the repository to a file.
  task :get_metadata_from_fedora => :environment do
    puts '''Not implemented yet. For now, use:
     curl -v \
         -H "Accept: application/ld+json" \
         -u $FEDORA_USER:$FEDORA_PASSWORD \
         "$FEDORA_HOSTNAME/fedora/rest/prod" \
         -o fedora_export.json'''
  end

  task :check_against_fedora => :environment do
    file_path = 'fedora_export.json'
    FedoraChecker.new(file_path).check
  end

  task :count_against_fedora => :environment do
    file_path = 'fedora_export.json'
    FedoraCounter.new(file_path).check
  end

end
