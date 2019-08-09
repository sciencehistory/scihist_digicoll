class AudioWorkShowDecorator < WorkShowDecorator


  # This is called by works_controller#show.
  def view_template
    'works/show_with_audio'
  end

  # Used in works controller to figure out whether it's appropriate to show an audio playlist
  # for a particular work.
  def self.show_playlist?(some_work)
    some_work.members.
      where(published: true).to_a.
      any? { | x| self.has_playable_audio_derivatives?(x) }
  end

  # This is the list of tracks for the playlist.
  def audio_members
    @audio_members ||= begin
      ordered_public_members.select { | x| self.class.has_playable_audio_derivatives?(x) }
    end
  end

  # Remove the representative from this list if it happens to be
  # at the head of the list. It's displayed separately in the template.
  def non_audio_members
    result = ordered_public_members.select { | x| !self.class.has_playable_audio_derivatives?(x) }
    result.delete_at(0) if result[0] == representative_member
    result
  end

  private

  def ordered_public_members
    @ordered_public_members ||= begin
      model.members.
        with_representative_derivatives.
        where(published: true).
        order(:position).
        to_a
    end
  end

  # To play properly, an audio track needs to meet the conditions below.
  # If it doesn't, it will be shown under non_audio_members.
  def self.has_playable_audio_derivatives?(member)
    member.kind_of?(Kithe::Asset) &&
      member.file &&
      member.content_type.start_with?("audio/") &&
      member.derivatives.present?
  end

end
