require 'rails_helper'

describe "oral history chunk factory" do
  let(:chunk) { build(:oral_history_chunk) }

  it "builds with timestamps" do
    expect(chunk).to be_present

    expect(chunk.embedding).to be_present
    expect(chunk.text).to be_present

    expect(chunk.other_metadata["timestamps"]).to be_present

    start_paragraph, end_paragraph = chunk.start_paragraph_number, chunk.end_paragraph_number
    expect(start_paragraph).to be_present
    expect(end_paragraph).to be_present

    expect(chunk.other_metadata["timestamps"][start_paragraph.to_s]).to have_key("included")

    expect(chunk.other_metadata["timestamps"][end_paragraph.to_s]).to have_key("included")
    expect(chunk.other_metadata["timestamps"][end_paragraph.to_s]).to have_key("previous")
  end

  describe "with_oral_history_content" do
    let(:chunk) { build(:oral_history_chunk, :with_oral_history_content) }

    it "creates" do
      expect(chunk).to be_present
      expect(chunk.oral_history_content).to be_present
      expect(chunk.oral_history_content.work).to be_present
      expect(chunk.oral_history_content.work.genre).to eq ["Oral histories"]
    end
  end
end
