class GeminiHandwritingTranscriptionComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def eligibility_problems
    GeminiHandwritingTranscriptionService.new(work: work).work_eligibility_problems
  end
end
