namespace :scihist do
  namespace :oh_microsite_import do

    require 'scihist_digicoll/oh_microsite_import_utilities'
    include OhMicrositeImportUtilities

    desc """
      Goes through all the oral histories and adds biographical metadata from files on the disk, for those missing them:

      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

      TODO:
      # Files are assumed to exist at tmp/oh_microsite_export/data/.
      # To specify another location for files:
      # FILES_LOCATION=/tmp/some_other_dir/ bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

    """
    task :import_interviewee_biographical_metadata => :environment do
      files = %w{name birth_date_1 birth_date_2 birth_date_3 birth_city birth_state birth_province birth_country death_date_1 death_date_2 death_date_3 death_city death_state death_province death_country education career honors}
      all_oral_histories = Work.where("json_attributes -> 'genre' ?  'Oral histories'")
      total_oral_histories = all_oral_histories.count
      works_updated = []
      errors = []
      files.each do |field|
        file_path = "bin/oh_microsite_export/data/#{field}.json"
        parsed = JSON.parse(File.read(file_path))
        unless parsed.is_a? Array
          puts "Error parsing #{file_path}"
          next
        end
        # puts "Starting #{field}"
        # progress_bar = ProgressBar.create(total: total_oral_histories, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
        progress_bar = nil
        all_oral_histories.find_each do |w|
          accession_num =  w.external_id.find { |id| id.category == "interview" }&.value
          unless accession_num
            progress_bar.log("ERROR: #{w.title}: no accession number.")  if progress_bar
            progress_bar.increment  if progress_bar
            next
          end
          relevant_rows = parsed.select{|row| row['interview_number'] == accession_num}
          if relevant_rows.count == 0
            # No relevant rows for this particular field for this particular interviewee.
            progress_bar.increment  if progress_bar
            next
          end
          begin
            if field == 'name'
              # TODO: The "name" query only involves the interviewee_name and interview_number tables.
              # Ascertain that the source record exists and is unique.
              # aka, perform processing here to ensure all relevant rows actually pertain to the same
              # interview (node id).
              if relevant_rows.empty?
                errors << "#{w.title} (#{w.friendlier_id}): could not find source record."
              end
              if relevant_rows.count > 1
                errors << "#{w.title} (#{w.friendlier_id}): More than one source record:\n#{relevant_rows.join("\n")}"
              end
            end
            OhMicrositeImportUtilities::Updaters.send(field, w.oral_history_content, relevant_rows)
            w.oral_history_content.save!
            works_updated << w
          rescue StandardError => e
            errors << "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
            if progress_bar.nil?
              puts "ERROR: #{w.title}: unable to save #{w.title}."
            else
              progress_bar.log("ERROR: #{w.title}: unable to save #{w.title}.")
              progress_bar.increment
            end
            next
          end
          progress_bar.increment if progress_bar
        end
      end
      puts "#{errors.join("\n")}"
      if works_updated.count == all_oral_histories.count
        puts "All oral histories in the digital collections were updated."
      else
        puts "Some oral histories in the digital collections were not updated."
      end
    end
  end
end