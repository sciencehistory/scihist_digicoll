# The tabs for Description/Transcription/Translation on Work show page,
# also including the actual content for Transcription and Translation -- the
# "Description" ccontent is  passed in as a content block!
#
#    render TranscriptionTabsComponent(transcription_pages: x, translation_pages: y) do
#       # description tab content
#    end
class TranscriptionTabsComponent < ApplicationComponent
  attr_reader :transcription_texts, :translation_texts, :work

  # @param work [Work]
  # @param transcription_pages [Array<Work::TextPage>]
  # @param translation_pages [Array<Work::TextPage>]
  def initialize(work:, transcription_texts:, translation_texts:)
    @work = work
    @transcription_texts = transcription_texts
    @translation_texts = translation_texts
  end
end
