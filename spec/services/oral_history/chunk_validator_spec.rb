require 'rails_helper'

describe OralHistory::ChunkValidator do
  let(:transcript_txt) do
    <<~EOS
      JONES: Did the spectrometer readings stabilize after we adjusted the focal length?

      SMITH: No, the baseline is still drifting by nearly five millivolts.

      JONES: That suggests the interference isn't optical; could it be a thermal leak?

      SMITH: I checked the seals, but the liquid nitrogen levels are dropping faster than expected.

      JONES: If we’re losing coolant that quickly, the entire sample is at risk.

      SMITH: I’ll start the emergency shutdown sequence before we lose the vacuum.
    EOS
  end

  let(:work) do
    build(:oral_history_work, :public_files,
      published: true,
      oral_history_content: OralHistoryContent.new(
        searchable_transcript_source: transcript_txt,
        oral_history_chunks: chunks
      )
    )
  end

  let(:oral_history_content) { work.oral_history_content }

  let(:validator) { described_class.new(oral_history_content)}


  describe "good chunks" do
    let(:chunks) do
      [
        build(:oral_history_chunk, start_paragraph_number: 1, end_paragraph_number: 4),
        build(:oral_history_chunk, start_paragraph_number: 4, end_paragraph_number: 6),
        build(:oral_history_chunk, start_paragraph_number: 5, end_paragraph_number: 6)
      ]
    end

    it "validates" do
      expect(validator.validate!).to eq true
    end
  end

  describe "missing all chunks" do
    let(:chunks) do
      []
    end

    it "raises" do
      expect {
        validator.validate!
      }.to raise_error(OralHistory::ChunkValidator::Failure, /expected to have chunks, but does not/)
    end
  end

  describe "does not reach end" do
    let(:chunks) do
      [
        build(:oral_history_chunk, start_paragraph_number: 1, end_paragraph_number: 2),
        build(:oral_history_chunk, start_paragraph_number: 2, end_paragraph_number: 4),
        build(:oral_history_chunk, start_paragraph_number: 4, end_paragraph_number: 5)
      ]
    end

    it "raises" do
      expect {
        validator.validate!
      }.to raise_error(OralHistory::ChunkValidator::Failure, /should end at paragraph 6/)
    end
  end

  describe "does not start at 1" do
    let(:chunks) do
      [
        build(:oral_history_chunk, start_paragraph_number: 2, end_paragraph_number: 3),
        build(:oral_history_chunk, start_paragraph_number: 3, end_paragraph_number: 4),
        build(:oral_history_chunk, start_paragraph_number: 4, end_paragraph_number: 6)
      ]
    end

    it "raises" do
      expect {
        validator.validate!
      }.to raise_error(OralHistory::ChunkValidator::Failure, /should start at paragraph 1/)
    end
  end

  describe "skips paragraphs" do
    let(:chunks) do
      [
        build(:oral_history_chunk, start_paragraph_number: 1, end_paragraph_number: 2),
        build(:oral_history_chunk, start_paragraph_number: 4, end_paragraph_number: 5),
        build(:oral_history_chunk, start_paragraph_number: 5, end_paragraph_number: 6)
      ]
    end

    it "raises" do
      expect {
        validator.validate!
      }.to raise_error(OralHistory::ChunkValidator::Failure, /chunks not properly consecutive/)
    end
  end

  describe "embargoed unavailable transcript" do
    let(:work) do
      build(:oral_history_work,
        members: [
          build(:asset_with_faked_file, :pdf, published: false, title: 'transcript', role: "transcript")
        ],
        published: true,
        oral_history_content: OralHistoryContent.new(
          searchable_transcript_source: transcript_txt,
          oral_history_chunks: chunks
        )
      )
    end

    let(:chunks) do
      [
        build(:oral_history_chunk, start_paragraph_number: 1, end_paragraph_number: 4),
        build(:oral_history_chunk, start_paragraph_number: 4, end_paragraph_number: 6),
        build(:oral_history_chunk, start_paragraph_number: 5, end_paragraph_number: 6)
      ]
    end

    it "should raise for having chunks" do
      expect {
        validator.validate!
      }.to raise_error(OralHistory::ChunkValidator::Failure, /Embargoed OH has 3 chunks/)
    end
  end
end
