module OralHistory
  # An individual footnote, output at bottom of page, with apparatus
  # to link back and forth to reference
  class FootnoteComponent < ApplicationComponent
    attr_reader :footnote_reference, :footnote_text

    def initialize(footnote_reference:, footnote_text:)
      @footnote_reference = footnote_reference
      @footnote_text = footnote_text
    end
  end
end
