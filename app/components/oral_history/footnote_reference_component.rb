module OralHistory

  # The HTML for an OHMS footnote reference, along with its inline tooltip.
  # Hovering over the link will show the tooltip; clicking on the link
  # will take you to the corresponding footnote at the bottom of the page via JS.
  # ( See `app/javascript/src/js/audio/ohms_footnotes.js` . )

  # The tooltip hover is based on:
  # http://hiphoff.com/creating-hover-over-footnotes-with-bootstrap/
  class FootnoteReferenceComponent < ApplicationComponent
    attr_reader :footnote_text, :number, :show_dom_id

    def initialize(footnote_text:, number:, show_dom_id:)
      @footnote_text = footnote_text
      @number = number
      @show_dom_id = show_dom_id
    end
  end
end
