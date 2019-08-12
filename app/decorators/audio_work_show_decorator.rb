class AudioWorkShowDecorator < WorkShowDecorator

  # Used in works controller to figure out whether
  # it's appropriate to show an audio playlist
  # for a particular work.
  # Doesn't care about the order of the members,
  # just whether any of the published ones have playable audio.
  def self.show_playlist?(some_work)
    some_work.members.
      where(published: true).
      any? { | x| self.has_playable_audio_derivatives?(x) }
  end

  # The list of tracks for the playlist.
  def audio_members
    @audio_members ||= begin
      ordered_public_members.select { | x| self.class.has_playable_audio_derivatives?(x) }
    end
  end

  # All the members to be displayed as thumbnails underneath the hero image.
  # As the audio members are already being "displayed" in the playlist, we don't need them in this list.
  def member_list_for_display
    super.reject { | x| audio_members.include?(x) }
  end

  private

  # To play properly, an audio track needs to meet the conditions below.
  # If it doesn't, it will be shown under non_audio_members.
  def self.has_playable_audio_derivatives?(member)
    member.kind_of?(Kithe::Asset) &&
      member.content_type&.start_with?("audio/") &&
      member.derivatives.present?
  end

end
