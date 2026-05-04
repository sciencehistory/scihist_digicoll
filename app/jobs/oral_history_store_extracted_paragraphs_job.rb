class OralHistoryStoreExtractedParagraphsJob < ApplicationJob

  # TODO extract this to a method in OralHistoryContent, yeah.
  def perform(oral_history_content)
    OralHistoryContent::ParagraphContainer.create(oral_history_content: oral_history_content)
  end
end
