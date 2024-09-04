# Background job to ensure a work's assets all have OCR (or don't) consistent
# with the Work#text_extraction
#
class WorkOcrCreatorRemoverJob < ApplicationJob
  if ScihistDigicoll::Env.lookup("active_job_ocr_queue").present?
    queue_as ScihistDigicoll::Env.lookup("active_job_ocr_queue")
  end

  # if the work has already been deleted before the job is run, just discard
  # This is how ActiveJob docs suggest to do that (https://guides.rubyonrails.org/active_job_basics.html#deserialization),
  # although actually this eats lots of other errors too, but we'll take it I guess?
  discard_on ActiveJob::DeserializationError

  def perform(work)
    WorkOcrCreatorRemover.new(work).process
  end
end
