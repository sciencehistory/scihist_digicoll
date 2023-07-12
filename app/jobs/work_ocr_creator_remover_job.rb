# Background job to ensure a work's assets all have OCR (or don't) consistent
# with the Work#ocr_requested_attribute
#
class WorkOcrCreatorRemoverJob < ApplicationJob
  def perform(work)
    WorkOcrCreatorRemover.new(work).process
  end
end
