class OpenaiAudioTranscribeJob < ApplicationJob
  def perform(asset, create_audio_derivative_if_needed: false)
    OpenaiAudioTranscribe.new(create_audio_derivative_if_needed: create_audio_derivative_if_needed).get_and_store_vtt_for_asset(asset)
  end

end
