class CreateCombinedAudioDerivativesJob < ApplicationJob


  def perform(work)
    deriv_creator = CombinedAudioDerivativeCreator.new(work)
    return unless deriv_creator.available_members?
    @sidecar = work.oral_history_content!
    @sidecar.combined_audio_derivatives_job_status = 'started'
    @sidecar.save!
    # Generate the derivatives:
    deriv_info = deriv_creator.generate
    if deriv_info.errors
      raise StandardError.new "Unable to create combined audio derivatives for work #{work.friendlier_id}: #{deriv_info.errors}"
    end
    # Upload to s3, then unlink local files:
    @sidecar.set_combined_audio_mp3!(deriv_info.mp3_file)
    deriv_info.mp3_file.unlink
    @sidecar.set_combined_audio_webm!(deriv_info.webm_file)
    deriv_info.webm_file.unlink
    # Update fingerprint and metadata:
    @sidecar.combined_audio_fingerprint = deriv_info.fingerprint
    @sidecar.combined_audio_component_metadata = { start_times: deriv_info.start_times }
    @sidecar.combined_audio_derivatives_job_status = 'succeeded'
    @sidecar.save!
  end

  rescue_from(StandardError) do |exception|
    @sidecar.combined_audio_derivatives_job_status = 'failed'
    @sidecar.save!
    raise
  end
end