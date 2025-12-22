require 'rails_helper'

describe OralHistory::AiConversationDisplayComponent, type: :component do
  let(:conversation) { create(:ai_conversation, :success_with_associations) }

  let(:component) { described_class.new(conversation) }

  describe "build_footnote_data" do
    let(:footnote_data) { component.build_footnote_data }
    let(:raw_footnote_json) { conversation.answer_json["footnotes"] }

    it "returns good footnote data" do
      expect(footnote_data.length).to eq raw_footnote_json.length

      0.upto(footnote_data.length - 1) do |index|
        expect(footnote_data[index].number).to eq raw_footnote_json[index]["number"]
        expect(footnote_data[index].paragraph_start).to eq raw_footnote_json[index]["paragraph_start"]
        expect(footnote_data[index].paragraph_end).to eq raw_footnote_json[index]["paragraph_end"]
        expect(footnote_data[index].quote).to eq raw_footnote_json[index]["quote"]

        expect( footnote_data[index].chunk).to be_present
        expect( footnote_data[index].chunk.reload).to be_present

        expect( footnote_data[index].work).to be_present
        expect( footnote_data[index].work).to be_kind_of(Work)
      end
    end

    it "can create links to footnote" do
      render_inline component

      expect(component.link_from_ai_conversation_footnote(footnote_data.first)).to eq(
        work_path(footnote_data.first.work.friendlier_id, anchor: "p=#{footnote_data.first.paragraph_start}")
      )
    end
  end

  describe "format_footnote_reference" do
    before do
      render_inline component
    end

    it "replaces footnote references with html for good footnote reference" do
      formatted_narrative= component.format_footnote_reference_html(conversation.answer_narrative)

      expect(formatted_narrative).not_to include "[^1]"
      expect(formatted_narrative).not_to include "[^2]"

      nokogiri = Nokogiri::HTML.fragment(formatted_narrative)

      component.footnote_list.each do |footnote_data|
        expect(nokogiri).to have_selector(".ai-conversation-display-footnote-reference##{footnote_data.ref_anchor}")
      end
    end

    it "removes html and such" do
      formatted_narrative = component.format_footnote_reference_html("This is < <bad> <script>stuff</script>")

      expect(formatted_narrative).to eq "This is &lt;  stuff"
      expect(formatted_narrative).to be_html_safe
    end

  end

  it "includes answer" do
    result = render_inline(component)

    answer = result.at_css(".answer-narrative")
    expect(answer).to be_present
    expect(answer.inner_html.strip).to eq component.format_footnote_reference_html(conversation.answer_narrative).strip
  end

  it "includes footnotes" do
    rendered = render_inline(component)

    component.footnote_list.each do |footnote_data|
      expect(page).to have_css("##{footnote_data.anchor}")
    end
  end
end
