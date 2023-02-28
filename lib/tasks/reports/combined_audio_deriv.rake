namespace :scihist do
  namespace :reports do
    desc "CSV report of combined audio derivative metadata, output directly to stdout. bundle exec rake scihist:reports:combined_audio_derivs > report.csv"
    task :combined_audio_derivs => :environment do
      oral_histories = Work.where("json_attributes -> 'genre' @> ?", "\"Oral histories\"")
      cmd = TTY::Command.new(output: Logger.new("/dev/null"))
      our_columns = ["friendlier_id"]
      ffprobe_columns = ["filename", "nb_streams", "nb_programs", "format_name", "format_long_name", "start_time", "duration", "size", "bit_rate", "probe_score"]
      csv_string = CSV.generate do |csv|
        csv << our_columns + ffprobe_columns
        oral_histories.find_each do |oral_history_work|
          next unless url = oral_history_work&.oral_history_content&.combined_audio_m4a&.url
          begin
            stats = JSON.parse(cmd.run("ffprobe", "-hide_banner", "-loglevel", "fatal",
                  "-show_format", "-print_format", "json",
                url).out).dig('format')
            row = [oral_history_work.friendlier_id] + ffprobe_columns.map{ |c| stats[c] }
            csv << row
          rescue TTY::Command::ExitError => e
            csv << [oral_history_work.friendlier_id, url]
          end
        end
      end
      puts csv_string
    end
  end
end
