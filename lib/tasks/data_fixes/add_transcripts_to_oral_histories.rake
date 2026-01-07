namespace :scihist do
  namespace :data_fixes do
    desc """
      Goes through all the oral histories and adds transcripts from a file on the disk, for those missing them:

      bundle exec rake scihist:add_transcripts_to_oral_histories
      Files are assumed to exist at /tmp/ohms_transcript_files/.

      To specify another location for files:
      FILES_LOCATION=/tmp/some_other_dir/ bundle exec rake scihist:add_transcripts_to_oral_histories

      To overwrite existing transcripts:
      OVERWRITE=true bundle exec rake scihist:add_transcripts_to_oral_histories
    """

    task :add_transcripts_to_oral_histories => :environment do

      files_location = ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_transcript_files/' : ENV['FILES_LOCATION']
      overwrite = ENV['OVERWRITE'].nil? ? false : (ENV['OVERWRITE'] == 'true')

      unless File.directory?(files_location)
        abort "ERROR: couldn't find the transcript files.\n"
      end

      progress_bar = ProgressBar.create(total: Work.where("json_attributes -> 'genre' ?  'Oral histories'").count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      Work.where("json_attributes -> 'genre' ?  'Oral histories'").find_each do |w|


        unless overwrite
          if w.oral_history_content!&.searchable_transcript_source.present?
            progress_bar.increment
            next
          end
        end

        accession_num =  w.oral_history_number
        unless accession_num
          progress_bar.log("ERROR: #{w.title}: no accession number.")
          progress_bar.increment
          next
        end

        filename = "#{files_location}#{accession_num}.txt"
        # There might be an extra 0 in the filename:
        filename = "#{files_location}#{accession_num.gsub(/^0+/, '')}.txt"  unless File.file?(filename)
        # ... Or a missing one.
        filename = "#{files_location}0#{accession_num}.txt" unless File.file?(filename)

        unless File.file?(filename)
          progress_bar.log("ERROR: #{w.title}: couldn't find a file on disk for #{accession_num}.")
          progress_bar.increment
          next
        end

        begin
          full_text = File.read(filename)
        rescue Errno::ENOENT => e
          progress_bar.log("ERROR: #{w.title}: unable to open #{filename}")
          progress_bar.increment
          next
        end

        # remove all control chars that aren't `\n`, replacing them with a space
        full_text.gsub!(/[\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F]/, ' ')

        # Now one way to remove HTML tags and unescape entitiesl like "&nbsp;" Also
        # let's turn a non-breaking space specifically into an ordinary space though.
        full_text.gsub!("&nbps;", " ")
        full_text = Nokogiri::HTML.fragment(full_text).text

        begin
          w.oral_history_content!.searchable_transcript_source = full_text
          w.oral_history_content.save!
        rescue StandardError => e
          progress_bar.log("ERROR: #{w.title}: unable to save transcript for #{w.title}. More info: #{e.inspect}")
          progress_bar.increment
          next
        end
        progress_bar.increment
      end
    end
  end
end
