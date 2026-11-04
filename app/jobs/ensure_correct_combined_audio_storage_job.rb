# If an oral history's combined audio is in the wrong (public vs restricted) storage
# for its availability_mode (or any on embargoed), delete it, then regenerate it if we can. The new file
# will be stored in the correct storage.
class EnsureCorrectCombinedAudioStorageJob < ApplicationJob
  def perform(oral_history_content)
    return if oral_history_content.combined_audio_in_correct_storage?

    # shrine deletes the old file on save
    oral_history_content.combined_audio_m4a = nil
    oral_history_content.combined_audio_fingerprint = nil
    oral_history_content.save!

    # does nothing if no available audio, eg embargoed
    CreateCombinedAudioDerivativesJob.perform_later(oral_history_content.work)
  end
end
