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
      # If the user is not allowed to :read
      # unpublished models
      policy = AccessPolicy.new(scope.context[:current_user])
      allowed_to_see_unpublished = (policy.can? :read, Work)
      # then filter out unpublished models.
      unless allowed_to_see_unpublished
        solr_params[:fq] ||= []
        solr_params[:fq] << "{!term f=published_bsi}1"
      end
    end
  end
end
