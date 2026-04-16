module OralHistory
  class AiConversationCitationComponent < ApplicationComponent
    attr_reader :citation_item

    def initialize(citation_item)
      @citation_item = citation_item
    end

    def link_to_source
      # If OHMS, we link directly to work page with anchor to take to specific paragraph
      if citation_item.work.oral_history_content.has_ohms_transcript?
        work_path(citation_item.work.friendlier_id, anchor: "p=#{citation_item.paragraph_start}")
      elsif citation_item.work.oral_history_content.available_by_request_manual_review?
        # they will need to request, just go to Work page, and trigger open request form
        work_path(citation_item.work.friendlier_id, anchor: "modal-auto-open=oh-request-trigger")
      else
        # otherwise, for now wit only staff viewers,  if it's not approval required, we
        # we let them see it, and go right , to PDF. May need to rethink if ever for other audience.
        view_transcript_pdf_path(citation_item.work)
      end
    end

  end
end
