class CreateCombinedAudioDerivativesJob < ApplicationJob
  def perform(work)
    # Generate the derivatives:
    deriv_info = CombinedAudioDerivativeCreator.new(work).generate
    sidecar = work.oral_history_content!
    # Upload to s3, then unlink local files:
    sidecar.set_combined_audio_mp3!(deriv_info.mp3_file)
    deriv_info.mp3_file.unlink
    sidecar.set_combined_audio_webm!(deriv_info.webm_file)
    deriv_info.webm_file.unlink
    # Update fingerprint and metadata:
    sidecar.combined_audio_fingerprint = deriv_info.fingerprint
    sidecar.combined_audio_component_metadata = { start_times: deriv_info.start_times }

    sidecar.save!
  end
end