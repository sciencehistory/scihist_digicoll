# The Work#show variant for Oral Histories with playable audio files, which
# show up in a fixed navbar.
#
class WorkOhAudioShowComponent < ApplicationComponent
  delegate :construct_page_title, :current_user, to: :helpers

  delegate  :m4a_audio_url, :derivatives_up_to_date?, to: :combined_audio_derivatives, prefix: "combined"

  attr_reader :work, :combined_audio_derivatives

  def initialize(work)
    @work = work

    # some helper methods for working with our derived combined audio file(s)
    @combined_audio_derivatives = CombinedAudioDerivatives.new(work)
  end

  # Cache the total list of published members, in other methods we'll search
  # through this in-memory to get members for various spots on the page.
  def all_members
    @all_members ||= begin
      members = work.members.includes(:leaf_representative)
      members = members.where(published: true) if current_user.nil?
      members = members.strict_loading # prevent accidental n+1 lazy-loading.
      members.order(:position).to_a
    end
  end

  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImageComponent.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)

    @representative_member = all_members.find { |m| m.id == work.representative_id }
  end


  def has_ohms_transcript?
    work&.oral_history_content&.has_ohms_transcript?
  end

  def has_ohms_index?
    work&.oral_history_content&.has_ohms_index?
  end

  def portrait_asset
    unless defined?(@portrait_asset)
      @portrait_asset = all_members.find {|mem| mem.role_portrait? }&.leaf_representative
    end

    @portrait_asset
  end

  def interviewee_biographies
    work.oral_history_content&.interviewee_biographies || []
  end
end
