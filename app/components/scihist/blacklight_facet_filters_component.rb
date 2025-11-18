module Scihist
  # override `Blacklight::Facets::FiltersComponent` *solely* to change the default value
  # in initializer for dependent suggestions_component -- to customize the
  # form field for entering suggestions.
  #
  # Also customize the classes!
  class BlacklightFacetFiltersComponent < Blacklight::Facets::FiltersComponent
    def initialize(
      suggestions_component: Scihist::BlacklightFacetSuggestComponent,
      classes: 'facet-filters mt-1 mb-3', # was 'facet-filters card card-body bg-light p-3 mb-3 border-0'
      **args
    )
      super
    end
  end
end
