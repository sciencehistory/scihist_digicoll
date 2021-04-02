namespace :scihist do
  namespace :oh_microsite_import do
    require 'scihist_digicoll/oh_microsite_import_utilities'
    include OhMicrositeImportUtilities
    desc """
      Updates the oral histories with interviewee biographical metadata
      extracted from JSON files in a particular directory.

      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

      # To specify another location for files:
      # FILES_LOCATION=/tmp/some_other_dir/ bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

      # Update only a specific set of digital collections works, based on their friendlier_id:
      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata[friendlier_id1,friendlier_id2,...]
    """
    task :import_interviewee_biographical_metadata => :environment do |t, args|

      if args.to_a.present?
        destination_records = Kithe::Work.where(friendlier_id: args.to_a)
        destination_records_label = "the records provided"
      else
        destination_records = Kithe::Work.where("json_attributes -> 'genre' ?  'Oral histories'")
        destination_records_label = "the digital collections"
      end


      files_location = ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_microsite_import_data/' : ENV['FILES_LOCATION']

      mapping_errors = []

      url_mapping = {}

      # Start with a basic check of the mapping using the name.sql file.
      names = JSON.parse(File.read("#{files_location}/name.json"))
      unless names.is_a? Array
        puts "Error parsing names data."
        abort
      end

      mismatches = []
      destination_accession_numbers = []

      destination_records.find_each do |w|
        accession_num =  w.external_id.find { |id| id.category == "interview" }&.value
        unless accession_num
          mapping_errors << "ERROR: #{w.title} ( #{w.friendlier_id} ): no accession number."
          next
        end
        destination_accession_numbers << accession_num
        relevant_rows = names.to_a.select{|row| row['interview_number'] == accession_num}

        mismatches << w unless relevant_rows.length == 1

        if relevant_rows.empty?
          mapping_errors << "#{w.title} (#{w.friendlier_id}): could not find source record."
        end
        if relevant_rows.length > 1
          mapping_errors << "#{w.title} (#{w.friendlier_id}): more than one source record:\n#{relevant_rows.join("\n")}"
        end


        url_mapping[relevant_rows.first['url_alias'].sub('https://oh.sciencehistory.org', '')] = "/works/#{w.friendlier_id}"

      end

      File.open("#{files_location}/oral_history_legacy_redirects.yml", 'w') do |f|
        f.write( url_mapping.map { | k, v | "#{k} : #{v}"}.join("\n"))
      end


      puts "Source records: #{names.count} (excludes unpublished)"
      puts "Source records still missing a matching destination record: #{names.map {|interview| interview['interview_number']}.reject{|id| destination_accession_numbers.include? id }.count}"
      puts "Destination records: #{destination_records.count}"
      puts "Destination records with an accession number: #{destination_accession_numbers.count}"
      puts
      puts "URL redirects file is at #{files_location}/oral_history_legacy_redirects.yml. It will need to be checked into config."
      puts

      if mapping_errors.present?
        puts "There were problems with the mapping. The following list of items will not be migrated:" if mapping_errors.present?
        puts "#{mapping_errors.join("\n")}"
      end


      validation_errors = []

      files = %w{ birth_date birth_city birth_state birth_province birth_country } +
              %w{ death_date death_city death_state death_province death_country } +
              #%w{ education career honors image interviewer}
              %w{ education career honors interviewer}

      works_updated = Set.new()


      # We run each query in turn.
      files.each do |field|
        progress_bar = ProgressBar.create(
          total: destination_records.count,
          format: "%a %t: |%B| %R/s %c/%u %p%% %e",
          title: field.ljust(15)
        )
        #progress_bar = nil

        results = JSON.parse(File.read("#{files_location}/#{field}.json"))

        # For each metatata field we iterate over the
        # entire list of oral histories. For each OH,
        # if the JSON file contains a value for the field, we set it.
        # Otherwise, we move on to the next oral history.
        destination_records.find_each do |w|

          # Don't try to migrate this item if there are zero or several potential OHs in the microsite:
          if mismatches.include? w
            progress_bar.increment  if progress_bar
            next
          end

          relevant_rows = select_rows(results, w)
          if relevant_rows.count == 0
            # No relevant rows for this particular field for this particular interviewee.
            progress_bar.increment  if progress_bar
            next
          end

          # OK, we have metadata for an interviewee. Let's try and update:
          begin
            if relevant_rows.map{|r| r[:interview_entity_id]}.uniq.count > 1
              validation_errors << "#{w.title} (#{w.friendlier_id}): Skipping #{field} since there was more than one source interview."
              progress_bar.increment unless progress_bar.nil?
              next
            end
            # Call the appropriate updater method:
            OhMicrositeImportUtilities::Updaters.
              send(field, w.oral_history_content, relevant_rows)
            w.oral_history_content.save!
          rescue StandardError => e
            # Unable to apply the new metadata. Note any errors pertaining to a particular work and field.
            validation_errors << "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
            if progress_bar.nil?
              puts "ERROR: #{w.title}: unable to save #{w.title}."
            else
              progress_bar.log("ERROR: #{w.title}: unable to save #{w.title}.")
              progress_bar.increment
            end
            next
          end
          # At this point the work has been updated without any problems.
          works_updated << w
          progress_bar.increment if progress_bar
        end
        # At this point all the oral histories have been updated with the metadata pertaining to `field`.
      end
      # At this point all the oral histories have been updated.



      # Print out validation errors and exit:
      if validation_errors.present?
        puts "#{validation_errors.join("\n")}"
      else
        puts "No validation errors."
      end

      ids_of_works_updated =  works_updated.map(&:friendlier_id).sort
      all_ids = destination_records.map(&:friendlier_id).sort

      if ids_of_works_updated == all_ids
        puts "All oral histories in #{destination_records_label} were updated."
      else
        puts "Some oral histories in #{destination_records_label} were not updated:"
        puts all_ids.reject {|fid| ids_of_works_updated.include? fid}
      end

    end
  end
end