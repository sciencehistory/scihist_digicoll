# The tabs for Description/Transcription/Translation on Work show page,
# also including the actual content for Transcription and Translation -- the
# "Description" ccontent is  passed in as a content block!
#
#    render TranscriptionTabsComponent(work: work) do
#       # description tab content
#    end
#
# NOTE: We will currently do a fresh fetch of ALL the work's viewable members in order to find and format
#       transcript/translation texts
#
#       This should be fine for our current actual use cases where manual transcription/translation works
#       have relatively few pages.
#
class TranscriptionTabsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  attr_reader :work

  # @param work [Work]
  # @param transcription_pages [Array<Work::TextPage>]
  # @param translation_pages [Array<Work::TextPage>]
  def initialize(work:)
    @work = work
  end

  def ordered_viewable_members
    @ordered_viewabler_members ||= work.ordered_viewable_members_excluding_pdf_source(current_user: current_user)
  end

  def transcription_texts
    @transcription_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :transcription)
  end

  def translation_texts
    @translation_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :english_translation)
  end
end
