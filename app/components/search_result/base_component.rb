module SearchResult
  # Display a  single hit in search results, common superclass for variants, such as for Work and Collection
  #
  # Meant to be an abstract superclass, which holds the view template .html.erb too. Not meant to be
  # used directly, sub-classes are expected to implement some methods used by the view template.
  class BaseComponent < ApplicationComponent
    # note order matters here! The fields listed first will listed first in snippet, and preferred
    # as far as first MAX_HIGHLIGHT_SNIPPETS included only.
    HIGHLIGHT_SOLR_FIELDS = ["searchable_fulltext_en", "searchable_fulltext_de", "searchable_fulltext_language_agnostic", "description_text4_tesimvo"]
    MAX_HIGHLIGHT_SNIPPETS = 3

    attr_reader :model, :child_counter, :cart_presence, :solr_document

    delegate :can?, :publication_badge, :search_on_facet_path, to: :helpers

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


    # Instantiated in SearchWithinCollectionWorkComponent.
    # Returns a string representing the box and folder, if the model is
    # a work and it's part
    # of an archival collection.
    # Otherwise, returns nil.
    def box_and_folder
    end

    # results in context highlights from solr, if available
    #
    # If multiple highlight results, we join them together with ellipses. We put ellipses at beginning
    # and end either way. html_safe string is returned, with the <em> tags around highlights.
    def search_highlights
      @search_highlights ||= begin
        highlights = HIGHLIGHT_SOLR_FIELDS.collect {|field| get_highlights(field) }.flatten.slice(0, MAX_HIGHLIGHT_SNIPPETS)
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
