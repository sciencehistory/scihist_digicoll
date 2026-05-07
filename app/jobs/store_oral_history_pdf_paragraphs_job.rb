class StoreOralHistoryPdfParagraphsJob < ApplicationJob

  # TODO extract this to a method in OralHistoryContent, yeah.
  def perform(oral_history_content, allow_failure_to_sync: false)
    OralHistoryContent::ParagraphContainer.create(oral_history_content: oral_history_content, allow_failure_to_sync: allow_failure_to_sync)
  end
end
