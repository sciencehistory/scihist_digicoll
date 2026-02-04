module OralHistory
  class AiConversationCitationComponent < ApplicationComponent
    attr_reader :citation_item

    def initialize(citation_item)
      @citation_item = citation_item
    end

    def link_to_source
      # this works for OHMS, will have to be changed/enhanced for others.
      work_path(citation_item.work.friendlier_id, anchor: "p=#{citation_item.paragraph_start}")
    end

  end
end
