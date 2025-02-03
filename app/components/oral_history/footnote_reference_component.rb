module OralHistory

  # The HTML for an OHMS footnote reference, along with its inline tooltip.
  # Hovering over the link will show the tooltip; clicking on the link
  # will take you to the corresponding footnote at the bottom of the page via JS.
  # ( See `app/javascript/src/js/audio/ohms_footnotes.js` . )

  # The tooltip hover is based on:
  # http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/
  class FootnoteReferenceComponent < ApplicationComponent
    attr_reader :footnote_text, :number, :show_dom_id, :link_content

    # @param footnote_text [String] the footnote itself. If marked html_safe, can contain html
    # @param number: [String] footnote number
    # @param show_dom_id: [Boolean] if true, link element will be given a dom ID
    #    false for cases wehre it would be illegal to give it a duplicate
    # @param link_content [String] optional additoinal content to put inside footnote
    #    link, before numeric footnote reference
    def initialize(footnote_text:, number:, show_dom_id: true, link_content:nil)
      @footnote_text = footnote_text
      @number = number
      @show_dom_id = show_dom_id
      @link_content = link_content
    end
  end
end
