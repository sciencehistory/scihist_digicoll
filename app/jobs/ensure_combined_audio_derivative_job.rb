# Normally does nothing unless the combined audio derivative is stale or in the wrong
# storage location; then deletes it, and re-creates it if there is any available audio.
#
# force: true always deletes and re-creates, even if the existing one looks current.
class EnsureCombinedAudioDerivativeJob < ApplicationJob

  def perform(work, force: false)
    logger.info("#{self.class}: Starting #{work.title}.")

    @sidecar = work.oral_history_content!
    return if !force && @sidecar.combined_audio_good?

    # delete first, so stale or wrongly-stored audio doesn't linger during re-create
    @sidecar.remove_combined_audio!

    deriv_creator = CombinedAudioDerivativeCreator.new(work, logger: logger)
    return unless deriv_creator.available_members?

    @sidecar.combined_audio_derivatives_job_status = 'started'
    @sidecar.save!
    # Generate the derivatives:
    deriv_info = deriv_creator.generate
    if deriv_info.errors
      raise StandardError.new "Unable to create combined audio derivatives for work #{work.friendlier_id}: #{deriv_info.errors}"
    end

    logger.debug("#{self.class}: Generation finished, uploading to S3...")

    # Upload to s3, then unlink local files:
    @sidecar.set_combined_audio_m4a!(deriv_info.m4a_file)
    deriv_info.m4a_file.unlink
    # Update fingerprint and metadata:
    @sidecar.combined_audio_fingerprint = deriv_info.fingerprint
    @sidecar.combined_audio_component_metadata = { start_times: deriv_info.start_times }
    @sidecar.combined_audio_derivatives_job_status = 'succeeded'
    @sidecar.save!

    logger.info("#{self.class}: Done with #{work.title}.")
  end

  rescue_from(StandardError) do |exception|
    if @sidecar
      @sidecar.combined_audio_derivatives_job_status = 'failed'
      @sidecar.save!
    end
    raise
  end
end
