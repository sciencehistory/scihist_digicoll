module OralHistory
  class AiConversationCitationComponent < ApplicationComponent
    attr_reader :citation_item

    # @param citation_item [OralHistory::AiConversationDisplayComponent::CitationItem]
    def initialize(citation_item)
      @citation_item = citation_item
    end

    def link_to_source
      # Both anchors, page uses whichever applies: highlighted transcript paragraph, or request/register
      # form if viewer lacks access. So link works even if login state changed since rendering.
      @link_to_source ||= work_path(citation_item.work.friendlier_id,
        anchor: "p=#{citation_item.paragraph_start}&th=#{transcript_highlight_value}&modal-auto-open=oh-request-trigger")
    end

    # request transcript highlight from OH page, it's imperfect and might
    # miss it but worth a try.  We try to catch some, one we can't
    # catch is if quote goes across multiple legacy OHMS transcript lines.
    def transcript_highlight_value
      #byebug if citation_item.quote =~ /Tuesday/
      quote = citation_item.quote

      # highlight can't do speaker labels, remove that if we have it.
      quote = quote.sub(OralHistory::PdfParagraphSplitter::SPEAKER_NAME_RE, '')

      # if there is '...' in there, it COULD be claude's own omission elipses
      # joining text that isn't next to each other, so stop there in the quote
      # Claude may use ... or unicode …
      quote = quote.split(/\.\.\.|…/).first

      words = quote.split(' ')

      # if that trimming hasn't left us with at least 4, nevermind,
      # we can't do it for now.
      return nil unless words.count > 4

      # now get first six words -- because highlighting more than that can be
      # distracting AND cause more words, more chance we'll run into something
      # that is un-highlightable such as split between legacy OHMS lines.
      words.first(6).join(" ")
    end
  end
end
