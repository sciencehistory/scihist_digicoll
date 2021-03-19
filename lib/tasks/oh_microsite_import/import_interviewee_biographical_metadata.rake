namespace :scihist do
  namespace :oh_microsite_import do
    desc """
      Goes through all the oral histories and adds biographical metadata from files on the disk, for those missing them:

      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

      # bundle exec rake scihist:add_transcripts_to_oral_histories
      # Files are assumed to exist at tmp/oh_microsite_export/data/.

      # To specify another location for files:
      # FILES_LOCATION=/tmp/some_other_dir/ bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata

    """

    task :import_interviewee_biographical_metadata => :environment do

      files =  %w{name birth_date_1 birth_date_2 birth_city birth_state birth_province birth_country death_date_1 death_date_2 death_city death_state death_province death_country honors education career}
      files =  %w{ birth_date_1 birth_date_2 birth_city birth_state birth_province birth_country}

      total_oral_histories = Work.where("json_attributes -> 'genre' ?  'Oral histories'").count
      puts total_oral_histories

      files.each do |file_name|
        file_path = "bin/oh_microsite_export/data/#{file_name}.json"
        parsed = JSON.parse(File.read(file_path))
        unless parsed.is_a? Array
          puts "Error parsing #{file_path}"
          next
        end
        # puts parsed.count

        progress_bar = ProgressBar.create(total: total_oral_histories, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
        Work.where("json_attributes -> 'genre' ?  'Oral histories'").find_each do |w|
          accession_num =  w.external_id.find { |id| id.category == "interview" }&.value
          unless accession_num
            progress_bar.log("ERROR: #{w.title}: no accession number.")
            progress_bar.increment
            next
          end
          relevant_rows = parsed.select{|row| row['interview_number'] == accession_num}

          puts "No #{file_name} rows found for #{w.title}" if relevant_rows.count == 0
          next if relevant_rows.count == 0

          begin

            #puts w.title
            #puts relevant_rows.first['interviewee_name']

            if %w{birth_date_1 birth_date_2 birth_city birth_state birth_province birth_country}.include? file_name
              w.oral_history_content!.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
            end
            if %w{birth_date_1 birth_date_2 death_city death_state death_province death_country}.include? file_name
              w.oral_history_content!.interviewee_death ||= OralHistoryContent::DateAndPlace.new
            end

            oral_history_content = w.oral_history_content!
            case file_name
            when 'birth_date_1'
              pp relevant_rows
            when 'birth_date_2'
              pp relevant_rows
            when 'birth_city'
              oral_history_content.interviewee_birth.city        = relevant_rows.first['birth_city']
            when 'birth_state'
              oral_history_content.interviewee_birth.state       = relevant_rows.first['birth_state']
            when 'birth_province'
              oral_history_content.interviewee_birth.province    = relevant_rows.first['birth_province']
            when 'birth_country'
              oral_history_content.interviewee_birth.country     = relevant_rows.first['birth_country']
            when 'death_city'
              oral_history_content.interviewee_death.city        = relevant_rows.first['death_city']
            when 'death_state'
              oral_history_content.interviewee_death.state       = relevant_rows.first['death_state']
            when 'death_province'
              oral_history_content.interviewee_death.province    = relevant_rows.first['death_province']
            when 'death_country'
              w.oral_history_content!.interviewee_death.country  = relevant_rows.first['death_country']
            end
            w.oral_history_content.save!
          rescue StandardError => e
            progress_bar.log("ERROR: #{w.title}: unable to save #{w.title}. More info: #{e.inspect}")
            progress_bar.increment
            next
          end
          progress_bar.increment
        end
      end
    end
  end
end