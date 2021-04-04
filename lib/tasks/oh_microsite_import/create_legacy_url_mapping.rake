namespace :scihist do
  namespace :oh_microsite_import do
    require 'scihist_digicoll/oh_microsite_import_utilities'
    include OhMicrositeImportUtilities
    desc """
      Creates a mapping of legacy URLS to current digital microsite URLs;
      prints it out to stdout.
      bundle exec rake scihist:oh_microsite_import:create_legacy_url_mapping
    """
    task :create_legacy_url_mapping => :environment do
      destination_records = Kithe::Work.where("json_attributes -> 'genre' ?  'Oral histories'")
      files_location = ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_microsite_import_data/' : ENV['FILES_LOCATION']
      urls = JSON.parse(File.read("#{files_location}/url.json"))
      unless urls.is_a? Array
        puts "Error parsing url data."
        abort
      end
      destination_records.find_each do |w|
        accession_num =  w.external_id.find { |id| id.category == "interview" }&.value
        next unless accession_num
        relevant_rows = urls.to_a.select{|row| row['interview_number'] == accession_num}
        next if relevant_rows.empty?
        relevant_rows.each do |row|
          source_url = row['url_alias'].sub('https://oh.sciencehistory.org', '')
          destination_url = "/works/#{w.friendlier_id}"
          puts  "#{source_url} : #{destination_url}"
        end
      end
    end
  end
end