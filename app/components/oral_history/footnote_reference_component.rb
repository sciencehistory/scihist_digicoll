module OralHistory

  # The HTML for an OHMS footnote reference, along with its inline tooltip.
  # Hovering over the link will show the tooltip; clicking on the link
  # will take you to the corresponding footnote at the bottom of the page via JS.
  # ( See `app/javascript/src/js/audio/ohms_footnotes.js` . )

  # The tooltip hover is based on:
  # http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/
  class FootnoteReferenceComponent < ApplicationComponent
    attr_reader :escaped_footnote_text, :number, :show_dom_id, :link_content, :footnote_is_html

    # @param footnote_text [String] the footnote itself.
    #
    # @param footnote_is_html [Boolean] if footnote is sanitized html code, default false
    #
    # @param number: [String] footnote number
    #
    # @param show_dom_id: [Boolean] if true, link element will be given a dom ID
    #    false for cases wehre it would be illegal to give it a duplicate
    #
    # @param link_content [String] optional additoinal content to put inside footnote
    #    link, before numeric footnote reference
    def initialize(footnote_text:, number:, show_dom_id: true, link_content:nil, footnote_is_html: false)
      # need to fully html-escape it for inclusion in ERB attribute, whether marked html_safe or not.
      @escaped_footnote_text = ERB::Util.html_escape(footnote_text.to_str)
      @number = number
      @show_dom_id = show_dom_id
      @link_content = link_content
      @footnote_is_html = footnote_is_html
    end
  end
end
