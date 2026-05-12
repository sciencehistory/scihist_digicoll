module OralHistory
  class AiConversationCitationComponent < ApplicationComponent
    attr_reader :citation_item

    # @param citation_item [OralHistory::AiConversationDisplayComponent::CitationItem]
    def initialize(citation_item)
      @citation_item = citation_item
    end

    def link_to_source
      @link_to_source ||= begin
        # If OHMS, we link directly to work page with anchor to take to specific paragraph
        if citation_item.can_link_to_html_transcript?
          work_path(citation_item.work.friendlier_id, anchor: "p=#{citation_item.paragraph_start}")
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
  end
end
