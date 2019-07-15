class HomepageController < ApplicationController
  def index

  end


  protected

  def featured_collection_image_link(work_id, title)
    work = Work.find_by_friendlier_id(work_id)
    return  view_context.link_to(title, "#") if work.nil?
    view_context.link_to(title, work_path(work_id))
  end
  helper_method :featured_collection_image_link

end