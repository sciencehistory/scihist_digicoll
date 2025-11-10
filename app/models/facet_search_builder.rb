class FacetSearchBuilder < Blacklight::FacetSearchBuilder
  include Blacklight::Solr::FacetSearchBuilderBehavior

  # shared logic with SearchBuilder that MUST be duplciated to avoid
  # subtle faulty behavior, see https://github.com/projectblacklight/blacklight/pull/3762
  include SearchBuilderBehavior
end
