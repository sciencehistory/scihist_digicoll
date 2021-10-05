module OralHistory
  # Yes, this could use some documentation, including what the footnotes_array is --
  # but it seems to be whatever OralHistoryContent::OhmsXml#footnote_array returns!
  class FootnotesSectionComponent < ApplicationComponent
    attr_reader :footnote_array

    def initialize(footnote_array:)
      @footnote_array = footnote_array
    end
  end
end
