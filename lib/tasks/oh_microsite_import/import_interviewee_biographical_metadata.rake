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
      else
        destination_records = Kithe::Work.where("json_attributes -> 'genre' ?  'Oral histories'")
      end
      files_location = ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_microsite_import_data/' : ENV['FILES_LOCATION']


      #PART 1: check mapping
      unpublished_duplicates_to_ignore = []

      mapping_errors = MappingErrors.new()
      names = JSON.parse(File.read("#{files_location}/name.json"))
      unless names.is_a? Array
        puts "Error parsing names data."
        abort
      end
      puts "Published source records: #{names.count}"
      destination_records.find_each do |w|
        accession_num =  get_accession_number(w)
        unless accession_num
          mapping_errors.record_no_accession_number(w)
          next
        end
        relevant_rows = names.to_a.select{|row| row['interview_number'] == accession_num}
        mapping_errors.record_no_match(w) if relevant_rows.empty?


        # SPECIAL CASE:
        # ONLY in the case of duplicate rows, *ignore* unpublished duplicates.
        if relevant_rows.length > 1
          relevant_rows.select{|arr| arr['published'] == 0}.each do |row|
            unpublished_duplicates_to_ignore << row
          end
          rejected_rows = relevant_rows.reject!{|arr| arr['published'] == 0}
        end
        # END SPECIAL CASE.

        mapping_errors.record_double_match(w, relevant_rows) if relevant_rows.length > 1

      end

      puts "Destination records: #{destination_records.count}"
      mapping_errors.print_errors_and_guesses(names)

      if unpublished_duplicates_to_ignore.present?
        puts "Found the following unpublished duplicates:"
        pp unpublished_duplicates_to_ignore
      end

      source_records_to_ignore = unpublished_duplicates_to_ignore.map {|v| v['interview_entity_id']}



      #PART 2: update records with good mappings.
      validation_errors = []
      metadata_files = %w{ birth_date birth_city birth_state birth_province birth_country } +
              %w{ death_date death_city death_state death_province death_country } +
              %w{ education career honors image interviewer}
      works_updated = Set.new()
      metadata_files.each do |field|
        progress_bar = ProgressBar.create(
          total: destination_records.count,
          format: "%a %t: |%B| %R/s %c/%u %p%% %e",
          title: field.ljust(15)
        )
        # progress_bar = nil
        results = JSON.parse(File.read("#{files_location}/#{field}.json"))

        # For each metatata field we iterate over the
        # entire list of oral histories. For each OH,
        # if the JSON file contains a value for the field, we set it.
        # Otherwise, we move on to the next oral history.
        destination_records.find_each do |w|
          # Don't try to migrate this item if there are zero or several potential OHs in the microsite:
          if mapping_errors.include? w
            progress_bar.increment if progress_bar; next
          end
          relevant_rows = select_rows(results, w)

          # SPECIAL CASE: ignore metadata pertaining to these unpublished duplicates:
          rejected_rows = relevant_rows.reject!{ |arr| unpublished_duplicates_to_ignore.include? arr['interview_entity_id'] }

          # No relevant rows for this particular field for this particular interviewee.
          if relevant_rows.count == 0
            progress_bar.increment  if progress_bar; next
          end
          # OK, we have metadata for an interviewee. Let's try and update:
          begin
            # Call the appropriate updater method:
            OhMicrositeImportUtilities::Updaters.
              send(field, w.oral_history_content, relevant_rows)
            w.oral_history_content.save!
          rescue StandardError => e
            # Unable to apply the new metadata. Note any errors pertaining to a particular work and field.
            validation_errors << "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
            progress_bar.increment if progress_bar; next
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
      puts "Works updated: #{works_updated.count}"
    end
  end
end