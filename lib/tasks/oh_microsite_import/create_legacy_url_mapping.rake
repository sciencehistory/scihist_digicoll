namespace :scihist do
  namespace :oh_microsite_import do
    require 'scihist_digicoll/oh_microsite_import_utilities/oh_microsite_import_utilities'
    desc """
      Creates a mapping of legacy URLS to current digital microsite URLs;
      prints it out to stdout.
      bundle exec rake scihist:oh_microsite_import:create_legacy_url_mapping
    """
    task :create_legacy_url_mapping => :environment do
      works = Kithe::Work.where("json_attributes -> 'genre' ?  'Oral histories'")
      urls = JSON.parse(File.read("#{files_location}/url.json"))
      files = JSON.parse(File.read("#{files_location}/file.json"))
      unless (urls.is_a? Array) && (files.is_a? Array)
        puts "Error parsing url data."
        abort
      end
      works.find_each do |w|
        accession_num =  w.external_id.find { |id| id.category == "interview" }&.value
        next unless accession_num
        relevant_urls  =  urls.to_a.select{|row| row['interview_number'] == accession_num}
        relevant_files = files.to_a.select{|row| row['interview_number'] == accession_num}
        next if relevant_urls.empty? && relevant_files.empty?
        relevant_urls.each do |row|
          source_url = row['url_alias'].sub('https://oh.sciencehistory.org', '')
          destination_url = "/works/#{w.friendlier_id}"
          puts  "\"#{source_url.downcase}\" : \"#{destination_url}\""
        end
        relevant_files.each do |row|
          destination_url = "/works/#{w.friendlier_id}"
          puts  "\"#{row['pdf_url'].downcase}\" : \"#{destination_url}\""      if row['pdf_url'].present?
          puts  "\"#{row['abstract_url'].downcase}\" : \"#{destination_url}\"" if row['abstract_url'].present?
        end
      end
    end
  end
end