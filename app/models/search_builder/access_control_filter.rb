class SearchBuilder
  # An extension to Blacklight's SearchBuilder (which is locally generated in our app),
  # that provides access control for public non/public items.
  #
  # For now, we just only allow published items to show up in search results. Later we
  # could let logged in users see non-published items, but we're starting with public
  # view for everyone.
  #
  # (We could also _not index_ non-published things, but kithe indexing routines might need
  # more features to add/remove something from index if it's pubished status changes).
  module AccessControlFilter
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:access_control_filter]
    end

    def access_control_filter(solr_params)
      solr_params[:fq] ||= []
      solr_params[:fq] << "{!term f=published_bsi}1"
    end
  end
end
