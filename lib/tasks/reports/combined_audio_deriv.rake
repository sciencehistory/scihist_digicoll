namespace :scihist do
  namespace :reports do
    desc "CSV report of combined audio derivative metadata, output directly to stdout. bundle exec rake scihist:reports:combined_audio_derivs > report.csv"
    task :combined_audio_derivs => :environment do
      oral_histories = Work.where("json_attributes -> 'genre' @> ?", "\"Oral histories\"")
      cmd = TTY::Command.new(output: Logger.new("/dev/null"))
      work_columns = ["title", "friendlier_id"]
      format_columns = ["filename", "nb_streams", "nb_programs", "format_name", "format_long_name", "start_time", "duration", "size"]
      stream_columns = ['bit_rate', 'sample_rate']
      csv_string = CSV.generate do |csv|
        csv << work_columns + format_columns + stream_columns
        oral_histories.find_each do |oral_history_work|
          next unless url = oral_history_work&.oral_history_content&.combined_audio_m4a&.url
          begin
            work_info = [oral_history_work.title, oral_history_work.friendlier_id]
            url = 'https://scihist-digicoll-production-derivatives.s3.amazonaws.com/combined_audio_derivatives/8b4b6f87-a316-4d47-bb20-7d32074945e4/combined_d83f2a70f07161ac9a73e107db164a10.m4a'
            stats = JSON.parse(cmd.run("ffprobe", "-hide_banner", "-loglevel", "fatal",
                  "-show_format", "-show_streams", "-print_format", "json",
                url).out)

            format_info = stats.dig('format')

            unless stats.dig('streams').count == 1
              # drop everything - a combined audio stream should never be stereo
              abort "ERROR: #{oral_history_work.friendlier_id} has more than one audio stream.\n"
            end

            stream_info = stats.dig('streams').first
            csv <<  work_info +
              format_columns.map{ |c| format_info[c] } +
              stream_columns.map{ |c| stream_info[c] }
          rescue TTY::Command::ExitError => e
            csv << work_info
          end
        end
      end
      puts csv_string
    end
  end
end