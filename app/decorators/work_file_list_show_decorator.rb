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
      members = model.members.includes(:leaf_representative)
      members = members.where(published: true) if current_user.nil?
      members = members.order(:position).to_a

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

end
