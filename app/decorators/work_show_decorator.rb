class WorkShowDecorator < Draper::Decorator
  delegate_all
  include Draper::LazyHelpers

  # This is called by works_controller#show.
  def view_template
    'works/show'
  end

  # Public members, ordered.
  # All the members to be displayed as thumbnails
  # underneath, and excluding, the hero image.
  # As the audio members (if any) are already being "displayed"
  # in the playlist, we don't need them in this list.
  def member_list_for_display
    @member_list_display ||= begin
      members = model.members.includes(:leaf_representative)
      members = members.where(published: true) if current_user.nil?
      members = members.order(:position).to_a
      # If the representative image is the first item in the list, don't show it twice.
      members.delete_at(0) if members[0] == representative_member
      members
    end
  end

  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImagePresenter. This will be an additional SQL fetch to
  # member_list_for_display, but a small targetted one-result one.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)

    @representative_member = model.representative
  end
end
