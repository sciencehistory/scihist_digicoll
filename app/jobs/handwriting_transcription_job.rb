class HandwritingTranscriptionJob < ApplicationJob
  def perform(work)
    # The work's text_extraction_mode may have changed while this job was waiting in the
    # queue; if so, don't pay for a transcription nobody wants any more.
    return unless work.handwriting_transcription_mode?

    GeminiHandwritingTranscriptionService.new(work: work).add_transcription!
  end
end
