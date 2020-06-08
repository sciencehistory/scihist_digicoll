# A single hit in search results, common superclass for variants, such as for Work and Collection
class ResultDisplay < ViewModel
  attr_reader :child_counter, :cart_presence, :solr_document

  # @param work [Work]
  # @param child_counter [ChildCountDisplayFetcher]
  # @param cart_presence [CartPresence]
  # @param solr_document [SolrDocument] Blacklight SolrDocument with solr result into
  def initialize(work,child_counter:, solr_document:nil, cart_presence:nil)
    @child_counter = child_counter
    @cart_presence = cart_presence
    @solr_document = solr_document
    super(work)
  end

  def display
    render "/presenters/index_result", model: model, solr_document: solr_document, view: self
  end

  # results in context highlights from solr, if available
  #
  # If multiple highlight results, we join them together with elipses. We put elipses at beginning
  # and end either way. html_safe string is returned, with the <em> tags around highlights.
  def search_highlights
    @search_highlights ||= begin
      highlights = solr_document && solr_document.has_highlight_field?("searchable_fulltext") && solr_document.highlight_field("searchable_fulltext")
      if highlights.present?
        "…".html_safe + safe_join(highlights, " …") + "…".html_safe
      else
        ""
      end
    end
  end
end
