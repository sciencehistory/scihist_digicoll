# The Work#show variant for Oral Histories with playable audio files, which
# show up in a fixed navbar.
#
class WorkOhAudioShowComponent < ApplicationComponent
  delegate :construct_page_title, :current_patron, to: :helpers

  delegate  :m4a_audio_url, :derivatives_up_to_date?, to: :combined_audio_derivatives, prefix: "combined"

  attr_reader :work, :combined_audio_derivatives

  def initialize(work)
    @work = work

    # some helper methods for working with our derived combined audio file(s)
    @combined_audio_derivatives = CombinedAudioDerivatives.new(work)
  end

  # By-request OH, and signed-in patron who can see its by-request files
  def can_view_only_as_registered_patron?
    return @can_view_only_as_registered_patron if defined?(@can_view_only_as_registered_patron)
    @can_view_only_as_registered_patron = !!work.oral_history_content&.available_by_request? &&
      !!helpers.current_patron&.can_access_oral_history?(work)
  end

  # Cache the total list of viewable members, in other methods we'll search
  # through this in-memory to get members for various spots on the page.
  def viewable_members
    @viewable_members ||= work.members_viewable_by(user: helpers.current_user, patron: helpers.current_patron).
      includes(:leaf_representative).
      strict_loading. # prevent accidental n+1 lazy-loading.
      order(:position).to_a
  end

  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImageComponent.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)

    @representative_member = viewable_members.find { |m| m.id == work.representative_id }
  end

  # could be OHMS transcript, or could be a PdfText extracted transcript
  def has_transcript?
    has_ohms_transcript? || (
      ScihistDigicoll::Env.lookup(:feature_display_pdf_paragraph_transcripts) &&
      work&.oral_history_content&.extracted_paragraph_container.present?
    )
  end

  def has_ohms_transcript?
    work&.oral_history_content&.has_ohms_transcript?
  end

  def has_ohms_index?
    work&.oral_history_content&.has_ohms_index?
  end

  def portrait_asset
    unless defined?(@portrait_asset)
      @portrait_asset = viewable_members.find {|mem| mem.try(:role_portrait?) }&.leaf_representative
    end

    @portrait_asset
  end

  def interviewee_biographies
    work.oral_history_content&.interviewee_biographies || []
  end
end
