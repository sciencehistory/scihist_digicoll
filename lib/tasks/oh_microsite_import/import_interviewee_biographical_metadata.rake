namespace :scihist do
  namespace :oh_microsite_import do
    require 'sequel'
    require 'scihist_digicoll/oh_microsite_import_utilities'
    include OhMicrositeImportUtilities
    desc """
      Updates the oral histories with interviewee biographical metadata
      extracted from JSON files in a particular directory.

      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

      TODO:
      # Query files are assumed to exist at tmp/oh_microsite_export/queries/.
      # To specify another location for files:
      # FILES_LOCATION=/tmp/some_other_dir/ bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata
    """
    task :import_interviewee_biographical_metadata => :environment do

      # If strict is true, proceed even if there are mismatches.
      strict = false

      DB = oh_database()

      files = ['name'] +
      %w{ birth_date_1 birth_date_2 birth_date_3 birth_city birth_state birth_province birth_country } +
      %w{ death_date_1 death_date_2 death_date_3 death_city death_state death_province death_country } +
      %w{ education career honors}

      all_oral_histories = Work.where("json_attributes -> 'genre' ?  'Oral histories'")
      total_oral_histories = all_oral_histories.count
      works_updated = Set.new()
      errors = []


      # Start with a basic check of the mapping using the name.sql file.
      results = DB[IO.read("bin/oh_microsite_export/queries/name.sql")]
      all_oral_histories.find_each do |w|
        accession_num =  w.external_id.find { |id| id.category == "interview" }&.value
        unless accession_num
          errors << "ERROR: #{w.title} ( #{w.friendlier_id} ): no accession number."
          next
        end
        relevant_rows = results.to_a.select{|row| row[:interview_number] == accession_num}
        if relevant_rows.empty?
          errors << "#{w.title} (#{w.friendlier_id}): could not find source record."
        end
        if relevant_rows.length > 1
          errors << "#{w.title} (#{w.friendlier_id}): More than one source record:\n#{relevant_rows.join("\n")}"
        end
      end

      if strict && errors.present?
        puts errors
        abort
      end
      # We run each query in turn.
      files.each do |field|
        progress_bar = ProgressBar.create(total: total_oral_histories, format: "%a %t: |%B| %R/s %c/%u %p%% %e", title: field.ljust(15))
        results = DB[IO.read("bin/oh_microsite_export/queries/#{field}.sql")]

        #progress_bar = nil
        # For each metatata field we iterate over the
        # entire list of oral histories. For each OH,
        # if the JSON file contains a value for the field, we set it.
        # Otherwise, we move on to the next oral history.
        all_oral_histories.find_each do |w|
          relevant_rows = select_rows(results, w)
          if relevant_rows.count == 0
            # No relevant rows for this particular field for this particular interviewee.
            progress_bar.increment  if progress_bar
            next
          end
          begin
            if relevant_rows.map{|r| r[:interview_entity_id]}.uniq.count > 1
              errors << "#{w.title} (#{w.friendlier_id}): Skipping #{field} since there was more than one source interview."
              next
            end
            # Call the appropriate updater method:
            OhMicrositeImportUtilities::Updaters.
              send(field, w.oral_history_content, relevant_rows)
            w.oral_history_content.save!
          rescue StandardError => e
            # Note any errors pertaining to a particular work and field.
            errors << "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
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

      # Print out errors and exit
      puts "#{errors.join("\n")}"
      if works_updated.map(&:friendlier_id).sort == all_oral_histories.map(&:friendlier_id).sort
        puts "All oral histories in the digital collections were updated."
      else
        puts "Some oral histories in the digital collections were not updated:"
        puts all_oral_histories.map(&:friendlier_id).reject!( works_updated.map(&:friendlier_id))
      end
    end
  end
end