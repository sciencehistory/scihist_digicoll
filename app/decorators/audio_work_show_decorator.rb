class AudioWorkShowDecorator < WorkShowDecorator

  # This is called by works_controller#show.
  def view_template
    'works/show_with_audio'
  end



  # The list of tracks for the playlist.
  def audio_members
    @audio_members ||= begin
      model.members.
        with_representative_derivatives.
        where(published: true).
        order(:position).
        select { | x| x.leaf_representative&.content_type&.start_with?("audio/") }
    end
  end


end
