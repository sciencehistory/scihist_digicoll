module OralHistory
  class AiConversationFootnoteReferenceComponent < ApplicationComponent
    delegate :link_from_ai_conversation_footnote, to: :helpers

    attr_reader :footnote_item

    # @param footnote_item [AiConversationDisplayComponent::FootnoteItem]
    def initialize(footnote_item)
      unless footnote_item.kind_of?(AiConversationDisplayComponent::FootnoteItem)
        raise ArgumentError.new("argument must be AiConversationDisplayComponent::FootnoteItem not #{footnote_item.class.name}")
      end

      @footnote_item = footnote_item
    end


  end
end
