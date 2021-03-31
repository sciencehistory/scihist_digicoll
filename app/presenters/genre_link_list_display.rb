# Just displays a list of genres with links, for use on search results and work show page
class GenreLinkListDisplay < ViewModel
  valid_model_type_names "Array" # of String names

  alias_method :genre_list, :model

  def display
    safe_join(
      genre_list.map { |g| link_to g, link_for_genre(g) },
      ", "
    )
  end

  private

  # Oral histories gets a special collection link, instead of to search results for genre
  def link_for_genre(genre_str)
    if genre_str == "Oral histories"
      collection_path(ScihistDigicoll::Env.lookup!(:oral_history_collection_id))
    else
      search_on_facet_path(:genre_facet, genre_str)
    end
  end

end
