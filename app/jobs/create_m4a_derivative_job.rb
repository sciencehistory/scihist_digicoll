class CreateM4aDerivativeJob < ApplicationJob
  def perform(audio_asset)
    if audio_asset.stored?
      begin
        logger.info("#{self.class}: Creating m4a for #{audio_asset.friendlier_id}.")
        audio_asset.create_derivatives(lazy: true)
        unless :m4a.in? audio_asset.file_derivatives.keys
         logger.info("ERROR: unable to create m4a for #{audio_asset.friendlier_id}")
        end
      rescue Shrine::FileNotFound => e
        logger.info("ERROR: Original missing for #{audio_asset.friendlier_id}")
      end
    else
      logger.info("ERROR: File not found in s3 storage: #{audio_asset.friendlier_id}")
    end
  end
end
