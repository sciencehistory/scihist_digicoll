class SearchBuilder
  # An extension to Blacklight's SearchBuilder (which is locally generated in our app),
  # that provides access control for public non/public items.
  #
  # Logged in users can see non-published items; the general public cannot.

  module AccessControlFilter
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:access_control_filter]
    end

    def access_control_filter(solr_params)
      unless can_see_unpublished?
        solr_params[:fq] ||= []
        solr_params[:fq] << "{!term f=published_bsi}1"
      end
    end

    def can_see_unpublished?
      user = scope.context[:current_user]
      AccessPolicy.new(user).can? :see_unpublished_items
    end

  end
end
