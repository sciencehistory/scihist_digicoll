namespace :scihist do
  namespace :data_fixes do
    desc "find stitched together audio derivs that are too short"
    task :find_corrupt_combined_audio => :environment do
      oral_histories = Work.where("json_attributes -> 'genre' @> ?", "\"Oral histories\"").where(published: true)

      corrupted_work_ids = []

      progress_bar = ProgressBar.create(total: oral_histories.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)


      cmd = TTY::Command.new(output: Logger.new("/dev/null"))

      oral_histories.find_each do |oral_history_work|
        deriv_creator = CombinedAudioDerivativeCreator.new(oral_history_work)
        eligible_members = deriv_creator.send(:published_audio_members)

        expected_duration = eligible_members.inject(0) do |sum, asset|
          sum + asset.file_metadata["duration_seconds"].to_f
        end

        mp3_url = oral_history_work&.oral_history_content&.combined_audio_mp3&.url
        webm_url = oral_history_work&.oral_history_content&.combined_audio_webm&.url

        if mp3_url
          actual_mp3_duration = begin
              JSON.parse(cmd.run("ffprobe", "-hide_banner", "-loglevel", "fatal",
                 "-show_format", "-print_format", "json",
               mp3_url).out).dig("format", "duration").to_f
          rescue TTY::Command::ExitError => e
            progress_bar.log("error at #{oral_history_work.friendlier_id}: #{e}")
            0
          end
        end

        if webm_url
          actual_webm_duration = begin
              JSON.parse(cmd.run("ffprobe", "-hide_banner", "-loglevel", "fatal",
                 "-show_format", "-show_error", "-print_format", "json",
                 webm_url).out).dig("format", "duration").to_f
          rescue TTY::Command::ExitError => e
            progress_bar.log("error at #{oral_history_work.friendlier_id}: #{e}")
            0
          end
        end

        # allow 2 second delta
        if (actual_mp3_duration && (expected_duration - actual_mp3_duration).abs > 2) ||
           (actual_webm_duration && (expected_duration - actual_webm_duration).abs > 2)

          progress_bar.log("bad one found #{oral_history_work.friendlier_id}, expected: #{expected_duration}; actual: #{actual_mp3_duration}, #{actual_webm_duration}")

          corrupted_work_ids << oral_history_work.friendlier_id
        end

        progress_bar.increment
      end

      puts "Bad works: #{corrupted_work_ids.count}"
      corrupted_work_ids.each do |id|
        puts "https://digital.sciencehistory.org/admin/works/#{id}"
      end
    end
  end
end
