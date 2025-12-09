module OralHistory
  class AiConversationFootnoteReferenceComponent < ApplicationComponent
    attr_reader :footnote_item

    # @param footnote_item [AiConversationDisplayComponent::FootnoteItem]
    def initialize(footnote_item)
      unless footnote_item.kind_of?(AiConversationDisplayComponent::FootnoteItem)
        raise ArgumentError.new("argument must be AiConversationDisplayComponent::FootnoteItem not #{footnote_item.class.name}")
      end

      @footnote_item = footnote_item
    end

    def link_from_footnote_item(footnote_item)
      # this works for OHMS, will have to be changed for others.
      work_path(footnote_item.work.friendlier_id, anchor: "p=#{footnote_item.paragraph_start}")
    end
  end
end
