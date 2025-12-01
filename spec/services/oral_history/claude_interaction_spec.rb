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
       ORAL HISTORY TITLE: Oral history interview with William John Bailey, 1986
       CHUNK ID: #{chunk1.id}
       SPEAKERS: SMITH
       PARAGRAPH NUMBERS: 12, 13, 14, 15
       TEXT:
       #{chunk1.text.chomp}
       ------------------------------
       ORAL HISTORY TITLE: Oral history interview with William John Bailey, 1986
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

    before do
      # we aren't testing much with the mock, but oh well
      allow(described_class::AWS_BEDROCK_CLIENT).to receive(:converse).and_return(
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
    end

    let(:json_return) {
      # we're only passing it through, it doesn't matter
      {
        "narrative" => "Some kind of answer [1]",
        "footnotes" => [
          { "number" => 1,
            "oral_history_title" => "Some title, 2001",
            "chunk_id" => "123",
            "paragraph_start" => 12,
            "paragraph_end" => 15,
            "quote" => "This is a quote"
          }
        ],
        "more_chunks_needed" => false,
        "answer_unavailable" => false
      }
    }

    it "returns json answer" do
      answer = interaction.get_answer
      expect(answer).to be_kind_of(Hash)
      expect(answer).to eq json_return
    end

    describe "clause response validation errors" do
      describe "missing more_chunks_needed" do
        let(:json_return) {
          {
            "narrative" => "Some kind of answer [^1]",
            "footnotes" => [
              { "number" => 1,
                "oral_history_title" => "Some title, 2001",
                "chunk_id" => "123",
                "paragraph_start" => 12,
                "paragraph_end" => 15,
                "quote" => "This is a quote"
              }
            ],
            "answer_unavailable" => false
          }
        }
        it "raises" do
          expect {
            answer = interaction.get_answer
          }.to raise_error(described_class::OutputFormattingError)
        end
      end

      describe "missing paragraph_start in footnote" do
        let(:json_return) {
          {
            "narrative" => "Some kind of answer [^1]",
            "footnotes" => [
              { "number" => 1,
                "oral_history_title" => "Some title, 2001",
                "chunk_id" => "123",
                "paragraph_end" => 15,
                "quote" => "This is a quote"
              }
            ],
            "more_chunks_needed" => false,
            "answer_unavailable" => false
          }
        }
        it "raises" do
          expect {
            answer = interaction.get_answer
          }.to raise_error(described_class::OutputFormattingError)
        end
      end

      describe "missing footnote" do
        let(:json_return) {
          {
            "narrative" => "Some kind of answer [^1]",
            "footnotes" => [
            ],
            "more_chunks_needed" => false,
            "answer_unavailable" => false
          }
        }
        it "raises" do
          expect {
            answer = interaction.get_answer
          }.to raise_error(described_class::OutputFormattingError)
        end
      end
    end
  end
end
