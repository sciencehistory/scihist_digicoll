module Scihist
  # Override of Blacklight::Facets::SugestComponent, which is somewhat confusingly
  # named, but is actually the *form input* for facet searching/limiting in 'more facets' box
  #
  # We want to customize it
  class BlacklightFacetSuggestComponent < Blacklight::Facets::SuggestComponent

  end
end
