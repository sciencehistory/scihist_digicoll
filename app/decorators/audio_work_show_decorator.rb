class AudioWorkShowDecorator < Draper::Decorator
  delegate_all
  include Draper::LazyHelpers

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

  def non_audio_members
    @non_audio_members ||= all_members.select do |m|
       !m.leaf_representative&.content_type&.start_with?("audio/")
     end
  end

  def asset_details(asset)
    details = []
    if asset.original_filename != asset.title
      details << asset.original_filename
    end
    if asset.content_type.present?
      details << ScihistDigicoll::Util.humanized_content_type(asset.content_type)
    end
    if asset.size.present?
      details << number_to_human_size(asset.size)
    end

    details.join(" — ")
  end
end
