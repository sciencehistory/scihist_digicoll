# Just displays a list of genres with links, for use on search results and work show page
class GenreLinkListComponent < ApplicationComponent
  attr_reader :genre_list

  delegate :search_on_facet_path, :oral_histories_collection_path, to: :helpers

  def initialize(genre_list)
    unless genre_list.is_a?(Array) && genre_list.all? {|e| e.is_a?(String)}
      raise ArgumentError.new("arg must be an Array of Strings")
    end
    @genre_list = genre_list
  end

  def call
    safe_join(
      genre_list.map { |g| link_to g, link_for_genre(g) },
      ", "
    )
  end

  private

  # Oral histories gets a special collection link, instead of to search results for genre
  def link_for_genre(genre_str)
    if genre_str == "Oral histories"
      oral_histories_collection_path
    else
      search_on_facet_path(:genre_facet, genre_str)
    end
  end

end
