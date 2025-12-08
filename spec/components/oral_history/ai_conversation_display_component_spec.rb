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

      expect(component.link_from_footnote_item(footnote_data.first)).to eq(
        work_path(footnote_data.first.work.friendlier_id, anchor: "p=#{footnote_data.first.paragraph_start}")
      )
    end
  end
end
