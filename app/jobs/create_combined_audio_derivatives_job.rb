class CreateCombinedAudioDerivativesJob < ApplicationJob

  def perform(work)
    logger.info("#{self.class}: Starting #{work.title}.")

    deriv_creator = CombinedAudioDerivativeCreator.new(work, logger: logger)
    return unless deriv_creator.available_members?
    @sidecar = work.oral_history_content!
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
    @sidecar.combined_audio_derivatives_job_status = 'failed'
    @sidecar.save!
    raise
  end
end
