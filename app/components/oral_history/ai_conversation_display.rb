module OralHistory
  class AiConversationDisplay < ApplicationComponent
    attr_reader :ai_conversation

    def initialize(ai_conversation)
      @ai_conversation = ai_conversation
    end

    def answer_narrative
      simple_format @ai_conversation.answer_json["narrative"]
    end

    def answer_footnote_list
      @ai_conversation.answer_json["footnotes"]
    end
  end
end
