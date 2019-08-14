class WorkShowDecorator < Draper::Decorator
  delegate_all
  include Draper::LazyHelpers

  # This is called by works_controller#show.
  def view_template
    'works/show'
  end

  # Overridden by audio_work_show_decorator.
  def audio_members
    []
  end

  # Public members, ordered.
  # All the members to be displayed as thumbnails
  # underneath, and excluding, the hero image.
  # As the audio members (if any) are already being "displayed"
  # in the playlist, we don't need them in this list.

  def member_list_for_display
    @member_list_display ||= begin
      members = model.members.
        with_representative_derivatives.
        where(published: true).
        order(:position).
        to_a

      members.reject! { | x| audio_members.include?(x) }
      # If the representative image is the first item in the list, don't show it twice.
      members.delete_at(0) if members[0] == representative_member
      members
    end
  end

  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImagePresenter. But instead of following the `representative`
  # association, let's find it from the `members`, to avoid an extra fetch.
  #
  # Does assume your represnetative is one of your members, otherwise it won't find it.
  def representative_member
    @representative_member ||= model.members.find { |m| m.id == model.representative_id }
  end
end
