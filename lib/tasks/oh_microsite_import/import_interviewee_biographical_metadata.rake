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

      files =  %w{name birth_date_1 birth_date_2 birth_date_3 birth_city birth_state birth_province birth_country death_date_1 death_date_2 death_date_3 death_city death_state death_province death_country education career honors }
      all_oral_histories = Work.where("json_attributes -> 'genre' ?  'Oral histories'")

      total_oral_histories = all_oral_histories.count

      works_updated = []
      errors = []

      files.each do |file_name|
        file_path = "bin/oh_microsite_export/data/#{file_name}.json"
        parsed = JSON.parse(File.read(file_path))
        unless parsed.is_a? Array
          puts "Error parsing #{file_path}"
          next
        end

        #puts "Starting #{file_name}"
        #progress_bar = ProgressBar.create(total: total_oral_histories, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
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
            #puts "No #{file_name} rows found for #{w.title}" if relevant_rows.count == 0
            progress_bar.increment  if progress_bar
            next
          end
          begin

            if %w{birth_date_1 birth_date_2 birth_date_3 birth_city birth_state birth_province birth_country}.include? file_name
              w.oral_history_content!.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
            end

            if %w{death_date_1 death_date_2 birth_date_3 death_city death_state death_province death_country}.include? file_name
              w.oral_history_content!.interviewee_death ||= OralHistoryContent::DateAndPlace.new
            end

            oral_history_content = w.oral_history_content!
            case file_name

            when 'name'
              if 1 == 0
                puts "Source info"
                puts relevant_rows.first['interviewee_name']
                puts relevant_rows.first['source_url']
                puts !(relevant_rows.count > 1)
                puts (relevant_rows.count > 0)

                puts "Destination info:"
                #puts accession_num
                #puts w.title
                puts "localhost:3000/admin/works/#{w.friendlier_id}/"
                puts w.title.include? relevant_rows.first['interviewee_name']
                puts "   "
              end

              if relevant_rows.empty?
                errors << "Could not find source record for #{w.title} ( #{w.friendlier_id} ) "
              end

              if relevant_rows.count > 1
                errors << "More than one source record for #{w.title} ( #{w.friendlier_id}) #{relevant_rows}"
              end

              works_updated << w

              #pp oral_history_content.work
              #pp admin_work_path(oral_history_content.work)
              # pp relevant_rows.first.interviewee_name
              # are there more than one relevant rows???
              # Are thare less than one relevant rows???
              # And all the destination items covered in the import?



            # TODO: Investigate which interviewees, if any, have data stored in
            # birth_date_1 and birth_date_2 and death_date_1 and death_date_2.
            # Why are those tables present, and do we need to migrate them?

            # when 'birth_date_1'
            #   pp relevant_rows
            # when 'birth_date_2'
            #   pp relevant_rows
            when 'birth_date_3'
              oral_history_content.interviewee_birth.date         = clean_up_date_string(relevant_rows.first['birth_date_3'])
            when 'birth_city'
              oral_history_content.interviewee_birth.city         = relevant_rows.first['birth_city']
            when 'birth_state'
              oral_history_content.interviewee_birth.state        = relevant_rows.first['birth_state']
            when 'birth_province'
              oral_history_content.interviewee_birth.province     = relevant_rows.first['birth_province']
            when 'birth_country'
              oral_history_content.interviewee_birth.country      = relevant_rows.first['birth_country']
            # when 'death_date_1'
            #   pp relevant_rows
            # when 'death_date_2'
            #   pp relevant_rows
            when 'death_date_3'
              oral_history_content.interviewee_death.date         = clean_up_date_string(relevant_rows.first['death_date_3'])
            when 'death_city'
              oral_history_content.interviewee_death.city         = relevant_rows.first['death_city']
            when 'death_state'
              oral_history_content.interviewee_death.state        = relevant_rows.first['death_state']
            when 'death_province'
              oral_history_content.interviewee_death.province     = relevant_rows.first['death_province']
            when 'death_country'
              w.oral_history_content!.interviewee_death.country   = relevant_rows.first['death_country']
            when 'education'
              w.oral_history_content.interviewee_school           = relevant_rows.map { |row| school_from_row(row) }
            when 'career'
              w.oral_history_content.interviewee_job              = relevant_rows.map { |row | job_from_row(row) }
            when 'honors'
              w.oral_history_content.interviewee_honor            = relevant_rows.map { |row | honor_from_row(row) }
            end # case
            w.oral_history_content.save!
          rescue StandardError => e
            if progress_bar.nil?
              puts "ERROR: #{w.title}"
              puts e.inspect
            else
              progress_bar.log("ERROR: #{w.title}: unable to save #{w.title}. More info: #{e.inspect}")  if progress_bar
              progress_bar.increment if progress_bar
            end
            next
          end
          progress_bar.increment if progress_bar
        end
      end
      if works_updated.count == all_oral_histories.count
        puts "All oral histories in the digital collections were updated."
      else
        puts "Some oral histories in the digital collections were not updated."
      end
      puts "Other errors: #{errors}"
    end
  end
end