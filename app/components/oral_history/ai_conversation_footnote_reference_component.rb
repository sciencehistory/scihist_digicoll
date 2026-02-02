module OralHistory
  # Legacy component for AiConversationDisplayJan2026, can be deleted when it is.
  class AiConversationFootnoteReferenceComponent < ApplicationComponent
    delegate :link_from_ai_conversation_footnote, to: :helpers

    attr_reader :footnote_item

    # @param footnote_item [AiConversationDisplayJan2026::FootnoteItem]
    def initialize(footnote_item)
      unless footnote_item.kind_of?(AiConversationDisplayJan2026::FootnoteItem)
        raise ArgumentError.new("argument must be AiConversationDisplayJan2026::FootnoteItem not #{footnote_item.class.name}")
      end

      @footnote_item = footnote_item
    end


  end
end
