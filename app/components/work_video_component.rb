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
class WorkVideoComponent < ApplicationComponent
  delegate :construct_page_title, :current_user, to: :helpers

  attr_reader :work

  def initialize(work)
    @work = work

    unless work.leaf_representative&.content_type&.start_with?("video/")
    	raise ArgumentError.new("work.leaf_representative must be a video to use #{self.class.name}")
    end
  end

  def video_asset
  	@video_asset = work.leaf_representative
  end
end
