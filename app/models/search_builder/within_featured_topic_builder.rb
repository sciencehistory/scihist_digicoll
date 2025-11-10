class SearchBuilder
  # Applies a limit to search just within a given featured topic.
  #
  # :slug needs to be provided in context.
  #
  # Used on FeaturedTopicController.
  #
  class WithinFeaturedTopicBuilder < ::SearchBuilder
    include WithinFeaturedTopicBuilderBehavior
  end
end
