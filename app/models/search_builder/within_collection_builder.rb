# frozen_string_literal: true

class SearchBuilder
  # Applies a limit to search just within a given collection, filtering on solr
  # field where we've stored the containing collection ids.
  #
  # :collection_id needs to be provided in context, the actual UUID pk of collection,
  # since that's what we index.
  #
  # Used on CollectionShowController search within a collection
  #
  # Blacklight 9 requires all custom search builder logic to be duplicated in a FacetSearchBuilder,
  # so all logic is located in the `WithinCollectionBuilderBehavior` module so it can be kept DRY.
  # See https://github.com/projectblacklight/blacklight/pull/3762
  #
  class WithinCollectionBuilder < ::SearchBuilder
    include WithinCollectionBuilderBehavior
  end
end
