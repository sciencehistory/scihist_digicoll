# frozen_string_literal: true

class SearchBuilder
  # Blacklight 9 requires all custom search builder logic to be duplicated in a FacetSearchBuilder,
  # so all logic is located in the `WithinCollectionBuilderBehavior` module so it can be kept DRY.
  # This one corresponds to the WithinCollectionBuilder
  # See https://github.com/projectblacklight/blacklight/pull/3762
  #
  class WithinCollectionFacetBuilder < ::FacetSearchBuilder
    include WithinCollectionBuilderBehavior
  end
end
