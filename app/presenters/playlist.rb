# Takes an array of Assets, which are assumed to be published and have audio derivatives,
# and constructs a playlist.

class Playlist < ViewModel

  valid_model_type_names "Array"

  attr_reader :array_of_tracks

  def initialize(model)
    super
    @array_of_tracks = model
    unless array_of_tracks.present?
      raise ArgumentError, 'Nil or empty array of tracks.'
    end
    unless array_of_tracks.all?{ |x| x.is_a? Asset }
      raise ArgumentError, 'Pass in an array of Assets.'
    end
  end

  def display
    render "/works/playlist", model: model, view: self
  end
end
