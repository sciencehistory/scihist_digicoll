# The tabs for Description/Transcription/Translation on Work show page,
# also including the actual content for Transcription and Translation -- the
# "Description" ccontent is  passed in as a content block!
#
#    render TranscriptionTabsComponent(work: work, members: already_fetched_members) do
#       # description tab content
#    end
#
class TranscriptionTabsComponent < ApplicationComponent
  attr_reader :work, :members

  # @param work [Work]
  # @param members [Work,Asset] pass in already fetched to prevent a re-fetch
  def initialize(work:,members:)
    @work = work
    @members = members
  end

  def transcription_texts
    @transcription_texts ||= Work::TextPage.compile(members, accessor: :transcription)
  end

  def translation_texts
    @translation_texts ||= Work::TextPage.compile(members, accessor: :english_translation)
  end
end
