# The tabs for Description/Transcription/AI Transcription/Translation on Work show page,
# also including the actual content for Transcription, AI Transcription and Translation -- the
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

  # Empty unless the gemini_htr_transcripts_feature_flag is on, so the AI Transcription
  # tab isn't shown to the public until we're ready.
  def handwriting_transcription_texts
    @handwriting_transcription_texts ||= if ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag)
      Work::TextPage.compile(members, accessor: :handwriting_transcription)
    else
      []
    end
  end

  def translation_texts
    @translation_texts ||= Work::TextPage.compile(members, accessor: :english_translation)
  end
end
