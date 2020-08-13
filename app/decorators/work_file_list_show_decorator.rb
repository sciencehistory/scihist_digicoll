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
class WorkFileListShowDecorator < Draper::Decorator
  delegate_all
  include Draper::LazyHelpers

  # This is called by works_controller#show.
  def view_template
    'works/work_file_list_show.html.erb'
  end

  # Public members, ordered.
  # Unlike standard show page, we don't have special treatment for representative hero.
  def member_list_for_display
    @member_list_display ||= begin
      members = all_members

      if current_user.nil?
        members = members.find_all(&:published?)
      end

      members
    end
  end

  def asset_details(asset)
    details = []

    if asset.content_type.present?
      details << ScihistDigicoll::Util.humanized_content_type(asset.content_type)
    end
    if asset.size.present?
      details << ScihistDigicoll::Util.simple_bytes_to_human_string(asset.size)
    end

    details.join(" — ")
  end

  def available_by_request_summary
    parts = []

    if available_by_request_pdf_count > 0
      parts << helpers.content_tag("b", helpers.pluralize(available_by_request_pdf_count,  "PDF transcript"), class: "font-italic")
    end

    if available_by_request_audio_count > 0
      parts << helpers.content_tag("b", helpers.pluralize(available_by_request_audio_count,  "audio recording file"), class: "font-italic")
    end

    helpers.safe_join(parts, ", and ")
  end

  def available_by_request_pdf_count
    @available_by_request_pdf_count ||= available_by_request_assets.find_all { |asset| asset.content_type == "application/pdf" }.count
  end

  def available_by_request_audio_count
    @available_by_request_audio_count ||= available_by_request_assets.find_all { |asset| asset.content_type.start_with?("audio/") }.count
  end

  def available_by_request_assets
    @available_by_request_assets ||= begin
      unless model.is_oral_history? &&
            model.oral_history_content &&
            (! model.oral_history_content.available_by_request_off?)
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
    @all_members = model.members.includes(:leaf_representative).order(:position).to_a
  end


end
