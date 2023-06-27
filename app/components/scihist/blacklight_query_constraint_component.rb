# query constraint as a live search box/form allowing you to change query,
# instead of just a label
#
# Referenced/used by our Scihist::BlacklightConstraintsComponent
module Scihist
  class Scihist::BlacklightQueryConstraintComponent < ApplicationComponent
    attr_reader :search_state

    # Blacklight passes in a bunch of keyword params when calling us, I'm not
    # sure how consistent it will be as an API, but the only one we need is
    # search_state, which hopefully will remain.
    def initialize(search_state:, **rest)
      @search_state = search_state
    end

    # We use these to generate hidden input fields to preserve other search context
    # when altering the search query.  This seems to be where Blacklight gets
    # them for the same thing, at least now at BL 8.0.0, hopefully it will work
    # properly and remain working.
    #
    # https://github.com/projectblacklight/blacklight/blob/13a8122fc6495e52acabc33875b80b51613d8351/app/components/blacklight/search_navbar_component.rb#L17-L24
    # https://github.com/projectblacklight/blacklight/blob/13a8122fc6495e52acabc33875b80b51613d8351/app/components/blacklight/search_bar_component.html.erb#L2
    #
    # We also remove :q as well as some other context we want to remove to have a "fresh" search with new query
    # but same facets etc.
    def search_context_params
      search_state.params_for_search.except(:q, :qt, :page, :utf8)
    end

    def current_search_q
      search_state.params_for_search[:q]
    end
  end
end
