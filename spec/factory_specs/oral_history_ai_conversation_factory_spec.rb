require 'rails_helper'

describe "oral history AI conversation factory" do
  describe "success_with_associations" do
    let(:ai_conversation) { build(:ai_conversation, :success_with_associations) }

    it "has footnotes with consistent data with chunk(s)" do
      expect(ai_conversation.answer_json).to be_present

      expect(ai_conversation.answer_json["introduction"]).to be_present
      expect(ai_conversation.answer_json["findings"]).to be_present

      ai_conversation.answer_json["findings"].each_with_index do |finding_json, index|
        expect(finding_json["answer"]).to be_present
        expect(finding_json["citations"]).to be_present

        finding_json["citations"].each do |citation_json|
          expect(citation_json["chunk_id"]).to be_present
          chunk_referenced = OralHistoryChunk.where(id: citation_json["chunk_id"]).first
          expect(chunk_referenced).to be_present

          expect(citation_json["paragraph_start"].to_i).to be_between(chunk_referenced.start_paragraph_number, chunk_referenced.end_paragraph_number)
          expect(citation_json["paragraph_end"].to_i).to be_between(chunk_referenced.start_paragraph_number, chunk_referenced.end_paragraph_number)
        end
      end
    end
  end
end
