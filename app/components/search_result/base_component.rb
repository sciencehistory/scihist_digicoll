module SearchResult
  # Display a  single hit in search results, common superclass for variants, such as for Work and Collection
  #
  # Meant to be an abstract superclass, which holds the view template .html.erb too. Not meant to be
  # used directly, sub-classes are expected to implement some methods used by the view template.
  class BaseComponent < ApplicationComponent
    attr_reader :model, :child_counter, :cart_presence, :solr_document

    delegate :current_user, :publication_badge, :search_on_facet_path, to: :helpers

    # @param work [Work]
    # @param child_counter [ChildCountDisplayFetcher]
    # @param cart_presence [CartPresence]
    # @param solr_document [SolrDocument] Blacklight SolrDocument with solr result into
    def initialize(model ,child_counter:, solr_document:nil, cart_presence:nil)
      @model = model
      @child_counter = child_counter
      @cart_presence = cart_presence
      @solr_document = solr_document
    end

    # results in context highlights from solr, if available
    #
    # If multiple highlight results, we join them together with ellipses. We put ellipses at beginning
    # and end either way. html_safe string is returned, with the <em> tags around highlights.
    def search_highlights
      @search_highlights ||= begin
        highlights = get_highlights("searchable_fulltext") + get_highlights("searchable_fulltext_language_agnostic")
        if highlights.present?
          "…".html_safe + safe_join(highlights, " …") + "…".html_safe
        else
          ""
        end
      end
    end

    def get_highlights(field)
      return [] unless solr_document
      return [] unless solr_document.has_highlight_field?(field)
      solr_document.highlight_field(field)
    end
  end
end
