# Individual work detail/show/view page for VIDEO
#
# Initially designed for a SINGLE video, which is the work #representative.
#
# If the work has any other members, they may not show up on display page... starting
# with the simple use case.
#
# This is very similar in some wyas to standard WorkImageShowComponent, but we make
# it a separate class instead of trying to use lots of conditionals in one class, betting
# that will be simpler overall, and allow them to diverge as more features are added.
class WorkVideoShowComponent < ApplicationComponent
  delegate :construct_page_title, to: :helpers

  attr_reader :work

  def initialize(work)
    @work = work

    unless work.leaf_representative&.content_type&.start_with?("video/")
    	raise ArgumentError.new("work.leaf_representative must be a video to use #{self.class.name}")
    end
  end

  def poster_src
    video_asset.file_derivatives(:thumb_large)&.url || asset_path("placeholderbox.svg")
  end

  def video_src_url
    video_asset.file_url(expires_in: 5.days.to_i)
  end

  # the representative, if it's visible to current user, otherwise nil!
  def video_asset
    return @video_asset if defined?(@video_asset)
    show_all_members = (access_policy.can? :read, Asset) && (access_policy.can? :read, Work)
  	@video_asset = (work.leaf_representative &&
      (work.leaf_representative.published? ||  show_all_members) &&
      work.leaf_representative) || nil
  end

  def private_label
    content_tag(:div, class: "private-badge-div") do
      content_tag(:span, title: "Private", class: "badge badge-warning") do
        '<i class="fa fa-exclamation-triangle" aria-hidden="true"></i>'.html_safe +
          " Private"
      end
    end
  end
end
