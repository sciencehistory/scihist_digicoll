require 'rails_helper'

describe OralHistory::ClaudeInteraction do
  let(:work) { create(:oral_history_work) }
  let(:chunk1) { create(:oral_history_chunk, oral_history_content: work.oral_history_content, speakers: ["SMITH"])}
  let(:chunk2) { create(:oral_history_chunk, oral_history_content: work.oral_history_content, speakers: ["SMITH", "JONES"], text: "Chunk 2")}

  let(:interaction) { described_class.new(question: "What are scientists like?") }

  describe "#format_chunks" do
    it "formats" do
      expect(interaction.format_chunks([chunk1, chunk2]).strip).to eq <<~EOS.strip
       ------------------------------
       CHUNK ID: #{chunk1.id}
       SPEAKERS: SMITH
       PARAGRAPH NUMBERS: 12, 13, 14, 15
       TEXT:
       #{chunk1.text.chomp}
       ------------------------------
       CHUNK ID: #{chunk2.id}
       SPEAKERS: SMITH, JONES
       PARAGRAPH NUMBERS: 12, 13, 14, 15
       TEXT:
       #{chunk2.text.chomp}
       ------------------------------
      EOS
    end
  end

  describe "#get_answer" do
    before do
      allow(OralHistoryChunk).to receive(:get_openai_embeddings) { |*args| [OralHistoryChunk::FAKE_EMBEDDING] * args.count }
    end

    let(:json_return) {
      # we're only passing it through, it doesn't matter
      {
        "narrative" => "The retrieved material does not contain information about collaborations with James D. Watson. The interviews discuss various scientific collaborations among other researchers in chemistry and physics, but none mention James D. Watson as a collaborator of any interview subject.",
        "footnotes" => [],
        "more_chunks_needed" => false,
        "answer_unavailable" => true
      }
    }

    it "returns json answer" do
      # we aren't testing much with the mock, but oh well
      expect(described_class::AWS_BEDROCK_CLIENT).to receive(:converse).and_return(
        OpenStruct.new(
          output: OpenStruct.new(
            message: OpenStruct.new(
              content: [
                OpenStruct.new(
                  # Claude is insisting on the markdown ``` fencing!
                  text: <<~EOS
                    ```json
                    #{json_return.to_json}
                     ```
                  EOS
                )
              ]
            )
          )
        )
      )

      answer = interaction.get_answer
      expect(answer).to be_kind_of(Hash)
      expect(answer).to eq json_return

    end
  end
end
