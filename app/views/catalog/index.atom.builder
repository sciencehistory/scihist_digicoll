# frozen_string_literal: true

#
# copy-paste-modify OVERRIDE of blacklight template at:
#    https://github.com/projectblacklight/blacklight/blob/v7.29.0/app/views/catalog/index.atom.builder
#
# We are mostly only modifying the individual document results (<entry> tags) -- while hypothethetically
# there might be a Blacklight want to have done this via configuration without overriding the whole
# index.atom.builder template, had trouble figuring it out, it seemed pretty hinky and potentially fragile,
# seemed better just to take control of the whole response, with some copy/paste.
#
# We now call out to an AtomEntry component for the entry element. We send it a Kithe::Model ActiveRecord
# object, which is available due to our use of the Kithe::BlacklightTools::BulkLoadingSearchService extension.

require 'base64'

xml.instruct!(:xml, encoding: "UTF-8")

xml.feed("xmlns" => "http://www.w3.org/2005/Atom",
         "xmlns:opensearch" => "http://a9.com/-/spec/opensearch/1.1/") do
  xml.title   t('blacklight.search.page_title.title', constraints: render_search_to_page_title(params), application_name: application_name)
  # an author is required, so we'll just use the app name
  xml.author { xml.name application_name }

  xml.link    "rel" => "self", "href" => url_for(search_state.to_h.merge(only_path: false))
  xml.link    "rel" => "alternate", "href" => url_for(search_state.to_h.merge(only_path: false, format: nil)), "type" => "text/html"
  xml.id      url_for(search_state.to_h.merge(only_path: false, format: nil))

  # Navigational and context links

  xml.link( "rel" => "next",
            "href" => url_for(search_state.to_h.merge(only_path: false, page: @response.next_page.to_s))
           ) if @response.next_page

  xml.link( "rel" => "previous",
            "href" => url_for(search_state.to_h.merge(only_path: false, page: @response.prev_page.to_s))
           ) if @response.prev_page

  xml.link( "rel" => "first",
            "href" => url_for(search_state.to_h.merge(only_path: false, page: "1")))

  xml.link( "rel" => "last",
            "href" => url_for(search_state.to_h.merge(only_path: false, page: @response.total_pages.to_s)))

  # "search" doesn't seem to actually be legal, but is very common, and
  # used as an example in opensearch docs
  xml.link( "rel" => "search",
            "type" => "application/opensearchdescription+xml",
            "href" => url_for(controller: 'catalog',action: 'opensearch', format: 'xml', only_path: false))

  # opensearch response elements
  xml.opensearch :totalResults, @response.total.to_s
  xml.opensearch :startIndex, @response.start.to_s
  xml.opensearch :itemsPerPage, @response.limit_value
  xml.opensearch :Query, role: "request", searchTerms: params[:q], startPage: @response.current_page

  # updated is required, for now we'll just set it to now, sorry
  xml.updated Time.current.iso8601

  @response.documents.each do |document|
    # A Document is a SolrDocument, it should have a `model` attribute with our
    # actual Kithe::Model AR objects, due to our use of Kithe::BlacklightTools::BulkLoadingSearchService
    if document.model
      xml << render(AtomEntryComponent.new(document.model))
    else
      Rails.logger.error("index.atom.builder: No model found for #{document.id}; out of date solr index?")
    end
  end
end
