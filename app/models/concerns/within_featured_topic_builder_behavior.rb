# Applies a limit to search just within a given featured topic.
#
# :slug needs to be provided in context.
#
# Used on FeaturedTopicController.
# Blacklight 9 requires all custom search builder logic to be duplicated in a FacetSearchBuilder,
# so it lives here to keep it DRY.
#
# See https://github.com/projectblacklight/blacklight/pull/3762
module WithinFeaturedTopicBuilderBehavior
  extend ActiveSupport::Concern

  included do
    self.default_processor_chain += [:within_featured_topic]
  end

  def within_featured_topic(solr_parameters)
    featured_topic = FeaturedTopic.from_slug(blacklight_params[:slug])
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << featured_topic.solr_fq
  end
end
