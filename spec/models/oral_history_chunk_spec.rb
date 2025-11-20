require 'rails_helper'

RSpec.describe OralHistoryChunk, type: :model do
  describe "dependent OralHistoryContent" do
    let(:work) { create(:oral_history_work) }
    let(:oral_history_content) { work.oral_history_content}
    let!(:oral_history_chunk) { create(:oral_history_chunk, oral_history_content: oral_history_content) }

    it "deletes chunk on change to ohms_xml_text" do
      expect(OralHistoryChunk.exists?(oral_history_chunk.id)).to be true

      oral_history_content.update!(ohms_xml_text: "something else")

      expect { oral_history_chunk.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not delete for other changes" do
      expect(OralHistoryChunk.exists?(oral_history_chunk.id)).to be true

      oral_history_content.update!(interviewee_biographies: [build(:interviewee_biography, name: "Guy, New")])
      expect(oral_history_content.interviewee_biographies.first.name).to eq "Guy, New"

      expect { oral_history_chunk.reload }.not_to raise_error
    end
  end
end
