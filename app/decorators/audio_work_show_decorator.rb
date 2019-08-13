class AudioWorkShowDecorator < WorkShowDecorator

  # This is called by works_controller#show.
  def view_template
    'works/show_with_audio'
  end

  # This is a class method. We're calling it from works controller
  # on all works (audio or not) to determine which decorator to use.
  # It looks at all the derivatives and stops, returning true, as soon as
  # it finds *one* that's audio.
  # Note: `audio_members` is an instance method to list *all* the audio
  # members for an item that we've already determined that it has at
  # least one audio track.
  # This method doesn't care about the order of the members,
  # just whether any of the published ones have audio.
  def self.show_playlist?(some_work)
    some_work.members.
      where(published: true).
      any? { | x| self.has_audio_derivatives?(x) }
  end

  # The list of tracks for the playlist.
  def audio_members
    @audio_members ||= begin
      ordered_public_members.select { | x| self.class.has_audio_derivatives?(x) }
    end
  end

  private

  # To play properly, an audio track needs to meet the conditions below.
  # Technically it should *also* have derivatives of the main audio asset,
  # but we are not testing for that here.
  def self.has_audio_derivatives?(member)
    member.kind_of?(Kithe::Asset) &&
      member&.content_type&.start_with?("audio/")
  end

end
