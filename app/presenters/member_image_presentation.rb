# A thumb, usually with 'view' and 'download' buttons below it. We call that the "member image" presentation.
# Naming is hard!
#
# (Descended from app/views/curation_concerns/base/_show_page_image.html.erb in chf_sufia)
#
# Could be a child work, could be an Asset. If it's a child work, it doesn't get view/download buttons,
# but instead gets an "Info" button linking to child work. (That is just a legacy decision cause it was
# easier to implement -- for child work that has _multiple_ Assets attached to it, unclear what a good UX
# is. It could be changed later.)
#
# The MemberImage can actually be of mutiple sizes, the large poster size for the "hero" section
# of page (pass in `size: :large`, :large size thumb will be used), or the more standard size (`size: :standard`,
# standard thumb, default).
#
# And can also be lazy-loading or not.
#
# You pass in a Work or Asset. Note that we will need to access the leaf_representative and it's
# derivatives, so if displaying a list of multiple (as you usually will be), you should
# eager load these, possibly with kithe `with_representative_derivatives` scope.
class MemberImagePresentation < ViewModel
  valid_model_type_names "Work", "Asset"

  alias_method :member, :model
  attr_reader :size, :lazy

  def initialize(work, size: :standard, lazy: false)
    @lazy = !!lazy
    @size = size
    super(work)
  end

  def display
    content_tag("div", class: "member-image-presentation") do
      content_tag("div", class: "thumb") do
        ThumbDisplay.new(representative_asset, thumb_size: size, lazy: lazy).display
      end +
      content_tag("div", class: "show-page-image-bar") do
        action_buttons_display
      end
    end
  end

  private

  def representative_asset
    member.leaf_representative
  end

  def action_buttons_display
    link_to("Download", "#", class: "btn btn-primary") + link_to("View", "#", class: "btn btn-primary")
  end

end
