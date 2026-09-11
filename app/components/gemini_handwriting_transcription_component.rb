class GeminiHandwritingTranscriptionComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def eligibility_problems
    GeminiHandwritingTranscriptionService.new(work: work).work_eligibility_problems
  end

  # TEMPORARY, for debugging -- raw contents of the transcript request log
  # we keep on the work, as pretty-printed JSON.
  def raw_transcript_requests_json
    JSON.pretty_generate(work.public_send(Work::HTR_TRANSCRIPT_REQUEST_ATTRIBUTE) || {})
  end
end
