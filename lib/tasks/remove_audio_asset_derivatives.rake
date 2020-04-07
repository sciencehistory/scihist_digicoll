namespace :scihist do
  desc """
    Goes through all derivatives of assets where key is either 'webm' or 'small_mp3', and removes them.
    NOTE: Remove this file once the task has been run in production; it won't be needed after that.
    bundle exec rake scihist:remove_audio_asset_derivatives
  """

  task :remove_audio_asset_derivatives => :environment do
    progress_bar = ProgressBar.create(total: Kithe::Derivative.where(key: ['webm', 'small_mp3']).count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    Kithe::Derivative.where(key: ['webm', 'small_mp3']).find_each(batch_size: 10) do |derivative|
      #Delete the derivative using ActiveRecord `destroy`:
      # shrine will take care of making sure
      # the actual bytestream in storage is deleted too.
      derivative.destroy
      progress_bar.increment
      Rails.logger.info(" Deleted #{derivative.key} for asset #{derivative.asset.friendlier_id} in '#{derivative.asset.parent.title}'")
    end
  end

end