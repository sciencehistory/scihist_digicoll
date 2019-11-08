class AudioWorkShowDecorator < Draper::Decorator
  delegate_all

  # This is called by works_controller#show.
  def view_template
    'works/show_with_audio'
  end



  # The list of tracks for the playlist.
  def all_members
    @all_members ||= begin
      members = model.members.with_representative_derivatives
      members = members.where(published: true) if current_user.nil?
      members.order(:position).to_a
    end
  end

  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImagePresenter. But instead of following the `representative`
  # association, let's find it from the `members`, to avoid an extra fetch.
  #
  # Does assume your representative is one of your members, otherwise it won't find it.
  def representative_member
    @representative_member ||= model.members.find { |m| m.id == model.representative_id }
  end

  def audio_members
    @audio_members ||= all_members.select { |m| m.leaf_representative&.content_type&.start_with?("audio/") }
  end

  def other_member_list
    @non_audio_members ||= all_members.select do |m|
       !m.leaf_representative&.content_type&.start_with?("audio/") &&
       m != representative_member
     end
  end

end
