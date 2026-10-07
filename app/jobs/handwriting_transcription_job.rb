class HandwritingTranscriptionJob < ApplicationJob
  def perform(work)
    GeminiHandwritingTranscriptionService.new(work: work).add_transcription!
  end
end
