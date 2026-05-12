module OralHistory
  class AiConversationCitationComponent < ApplicationComponent
    attr_reader :citation_item

    # @param citation_item [OralHistory::AiConversationDisplayComponent::CitationItem]
    def initialize(citation_item)
      @citation_item = citation_item
    end

    def link_to_source
      @link_to_source ||= begin
        # If OHMS, we link directly to work page with anchor to take to specific paragraph,
        # with some search-term highlighting triggered.
        if citation_item.can_link_to_html_transcript?
          work_path(citation_item.work.friendlier_id, anchor: "p=#{citation_item.paragraph_start}&th=#{transcript_highlight_value}")
        elsif citation_item.work.oral_history_content.available_by_request_manual_review?
          # they will need to request, just go to Work page, and trigger open request form
          work_path(citation_item.work.friendlier_id, anchor: "modal-auto-open=oh-request-trigger")
        else
          # otherwise, for now wit only staff viewers,  if it's not approval required, we
          # we let them see it, and go right , to PDF. May need to rethink if ever for other audience.
          #
          # If we have a page number, we can try linking to page, which some
          # browsers can handle. (mobile usually cannot)
          #  oops, this doens't work yet, we need to take account offset to do this, although
          #  we do have offset now and could do that...
          #anchor = "page=#{citation_item.page_number}" if citation_item.page_number
          view_transcript_pdf_path(citation_item.work)
        end
      end
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
