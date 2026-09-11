class HandwritingTranscriptionJob < ApplicationJob
  def perform(work)
    GeminiHandwritingTranscriptionService.new(work: work).call
  end
end
