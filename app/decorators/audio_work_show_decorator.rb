class AudioWorkShowDecorator < WorkShowDecorator

  # This is a class method. We're calling it from works controller
  # on all works (audio or not) to determine which decorator to use.
  # It looks at all the derivatives and stops, returning true, as soon as
  # it finds *one* that's audio.
  # Note: `audio_members` is an instance method to list *all* the audio
  # members for an item that we've already determined that it has at
  # least one playable audio track.
  # This method doesn't care about the order of the members,
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
  def self.has_playable_audio_derivatives?(member)
    member.kind_of?(Kithe::Asset) &&
      member&.content_type&.start_with?("audio/") &&
      member.derivatives.present?
  end

end
