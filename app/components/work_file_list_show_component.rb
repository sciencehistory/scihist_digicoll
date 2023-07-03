# A work show page, motivated by Oral Histories that require a form fill out
# to get access to media files, and do not have OHMS or publicly playable audio.
#
# Our normal work show page really highlights thumbnails, including a large poster
# thumb. But PDFs (and a/v) aren't really image media, and aren't really served by that.
# So this one has more of a file-listing approach.
#
# Might be usable in other contexts where you want a more file-listing approach,
# but links and download options might not be right, beware. We do not ever
# include a link to the viewer here, and don't do DownloadOoptions, just
# a single download button.
#
class WorkFileListShowComponent < ApplicationComponent
  delegate :construct_page_title, :can_see_unpublished_records?, to: :helpers

  attr_reader :work

  def initialize(work)
    @work = work
  end

  # Public members, ordered.
  # Unlike standard show page, we don't have special treatment for representative hero.
  def member_list_for_display
    @member_list_display ||= begin
      members = all_members

      unless can_see_unpublished_records?
        members = members.find_all(&:published?)
      end

      # omit "portrait" role
      members = members.find_all {|m| ! m.role_portrait? }

      members
    end
  end

  def portrait_asset
    unless defined?(@portrait_asset)
      @portrait_asset = all_members.find {|mem| mem.published? && mem.role_portrait? }&.leaf_representative
    end

    @portrait_asset
  end

  def interviewee_biographies
    work.oral_history_content&.interviewee_biographies || []
  end

  def available_by_request_pdf_count
    @available_by_request_pdf_count ||= available_by_request_assets.find_all { |asset| asset.content_type == "application/pdf" }.count
  end

  def available_by_request_audio_count
    @available_by_request_audio_count ||= available_by_request_assets.find_all { |asset| asset.content_type&.start_with?("audio/") }.count
  end

  def request_button_name
    if @work.oral_history_content.available_by_request_automatic?
      "Get Access"
    else
      "Request Access"
    end
  end

  def available_by_request_assets
    @available_by_request_assets ||= begin
      unless work.is_oral_history? &&
            work.oral_history_content &&
            (! work.oral_history_content.available_by_request_off?)
        []
      else
        all_members.find_all { |member| member.kind_of?(Asset) && !member.published? && member.oh_available_by_request? }
      end
    end
  end

  private

  # We need to slice and dice the members in a couple ways, so just load them all in,
  # but we should never show this to the public
  def all_members
    @all_members = work.members.includes(:leaf_representative).order(:position).strict_loading.to_a
  end


end
