require 'rails_helper'

describe OralHistory::AiConversationDisplayComponent, type: :component do
  let(:conversation) { create(:ai_conversation, :success_with_associations) }

  let(:component) { described_class.new(conversation) }

  it "includes introduction" do
    result = render_inline(component)

    answer = result.at_css(".answer-introduction")
    expect(answer).to be_present
    expect(answer.inner_html.strip).to eq conversation.answer_json["introduction"].strip
  end

  it "includes findings with citations" do
    rendered = render_inline(component)

    expect(page).to have_css("ul.ai-conversation-findings li", count: conversation.answer_json["findings"].count)
    conversation.answer_json["findings"].each do |finding|
      expect(page).to have_css("ul.ai-conversation-findings li", text: /#{finding["answer"]}/)
    end
  end
end
