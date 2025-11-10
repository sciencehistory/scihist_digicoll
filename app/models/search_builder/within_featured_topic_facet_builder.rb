class SearchBuilder
  # Blacklight 9 requires all custom search builder logic to be duplicated in a FacetSearchBuilder,
  # so all logic is located in the `WithinFeaturedTopicBuilderBehavior` module so it can be kept DRY.
  # This one corresponds to the WithinFeaturecTopicBuilder
  #
  # See https://github.com/projectblacklight/blacklight/pull/3762
  class WithinFeaturedTopicFacetBuilder < ::FacetSearchBuilder
    include WithinFeaturedTopicBuilderBehavior
  end
end
