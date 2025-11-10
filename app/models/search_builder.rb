# frozen_string_literal: true
#
# Blacklight 9 requires all custom search builder logic to be duplicated in a FacetSearchBuilder,
# so please do all customization in the `SearchBuilderBehavior` module so it can be kept DRY.
# See https://github.com/projectblacklight/blacklight/pull/3762
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior

  include SearchBuilderBehavior
end
