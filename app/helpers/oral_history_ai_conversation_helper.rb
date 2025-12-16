module OralHistoryAiConversationHelper
  # produces a link out to Oral History source from an AI Conversation footnote
  #
  # @param footnote_item [OralHistory::AiConversationDisplayComponent::FootnoteItem]
  def link_from_ai_conversation_footnote(footnote_item)
    # this works for OHMS, will have to be changed/enhanced for others.
    work_path(footnote_item.work.friendlier_id, anchor: "p=#{footnote_item.paragraph_start}")
  end
end
