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
      else
        # otherwise, for now, to PDF -- will need to be logged in staff to see many of these,
        # for now this demo is only for staff. May need to rethink if ever for other audience.
        view_transcript_pdf_path(citation_item.work)
      end
    end

  end
end
