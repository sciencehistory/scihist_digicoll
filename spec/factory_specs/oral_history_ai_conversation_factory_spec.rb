require 'rails_helper'

describe "oral history AI conversation factory" do
  describe "success_with_associations" do
    let(:ai_conversation) { build(:ai_conversation, :success_with_associations) }

    it "has footnotes with consistent data with chunk(s)" do
      expect(ai_conversation.answer_json).to be_present

      expect(ai_conversation.answer_json["narrative"]).to be_present
      expect(ai_conversation.answer_json["footnotes"]).to be_present

      ai_conversation.answer_json["footnotes"].each_with_index do |footnote_json, index|
        expect(footnote_json["number"]).to eq index+1
        expect(footnote_json["quote"]).to be_present

        expect(footnote_json["chunk_id"]).to be_present
        chunk_referenced = OralHistoryChunk.where(id: footnote_json["chunk_id"]).first
        expect(chunk_referenced).to be_present

        expect(footnote_json["paragraph_start"].to_i).to be_between(chunk_referenced.start_paragraph_number, chunk_referenced.end_paragraph_number)
        expect(footnote_json["paragraph_end"].to_i).to be_between(chunk_referenced.start_paragraph_number, chunk_referenced.end_paragraph_number)
      end
    end
  end
end
