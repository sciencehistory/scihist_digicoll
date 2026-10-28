class HandwritingTranscriptionJob < ApplicationJob
  def perform(work)
    # The work's text_extraction_mode may have changed while this job was waiting in the
    # queue; if so, don't pay for a transcription nobody wants any more.
    unless work.handwriting_transcription_mode?
      Rails.logger.info("#{self.class}: not transcribing work #{work.friendlier_id}, as its text_extraction_mode is no longer handwriting_transcription (it's #{work.text_extraction_mode.inspect})")
      return
    end

    GeminiHandwritingTranscriptionService.new(work: work).add_transcription!
  end
end
