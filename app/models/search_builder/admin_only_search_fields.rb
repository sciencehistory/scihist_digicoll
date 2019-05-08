class SearchBuilder
  # An extension to Blacklight's SearchBuilder (which is locally generated in our app), such
  # that logged in users will have additional field(s) added to their solr `qf` and `pf` fields,
  # so our logged in users (which are staff), can search staff-only fields.
  #
  # See the indexer classes (eg WorkIndexer) to see what is put in what admin-only fields.
  module AdminOnlySearchFields
    extend ActiveSupport::Concern

    mattr_accessor :admin_only_search_fields
    self.admin_only_search_fields = [
      "admin_only_text_tesim"
    ]

    included do
      self.default_processor_chain += [:include_admin_only_search_fields]
    end

    def include_admin_only_search_fields(solr_params)
      if scope.context[:current_user]
        solr_params["qf"] << " " << admin_only_search_fields.join(" ")
        solr_params["qf"] << " " << admin_only_search_fields.join(" ")
      end
    end
  end
end
