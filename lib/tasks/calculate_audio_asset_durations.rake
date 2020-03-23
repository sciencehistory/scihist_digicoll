namespace :scihist do
  desc """
    Goes through all the oral histories and generates combined audio derivatives for
    those missing them:

    bin/bundle exec rake scihist:calculate_audio_asset_durations
  """

  task :calculate_audio_asset_durations => :environment do
    begin
      cmd = TTY::Command.new
      duration_command = ['ffprobe', '-v', 'error',
        '-show_entries', 'format=duration', '-of',
        'default=noprint_wrappers=1:nokey=1' ]
      Asset.find_each(batch_size: 10) do |a|
        next unless a.content_type && (a.content_type.start_with?("audio"))
        next unless a.stored?
        # If we already have a duration stored, assume it's correct.
        next if a.file.metadata['duration']

        new_temp_file = Tempfile.new(['temp_', a.file.metadata['filename'].downcase], :encoding => 'binary')
        a.file.open(rewindable:false) do |input_audio_io|
          new_temp_file.write input_audio_io.read until input_audio_io.eof?
        end
        options = duration_command.dup.append(new_temp_file.path)
        duration = cmd.run(*options).out.strip.to_f

        # Only store the duration if it's a valid Float.
        if Float(duration, exception: false)
          a.file.metadata['duration'] = duration
          a.save!
        end
        new_temp_file.unlink
        rescue Aws::S3::Errors::NotFound
          new_temp_file.unlink
          next
        end
      end
    end
end