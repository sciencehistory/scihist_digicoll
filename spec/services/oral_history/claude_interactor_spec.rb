require 'rails_helper'

describe OralHistory::ClaudeInteractor do
  include AwsBedrockClaudeMockResponse

  let(:work) { create(:oral_history_work) }
  let(:chunk1) { create(:oral_history_chunk, oral_history_content: work.oral_history_content, speakers: ["SMITH"])}
  let(:chunk2) { create(:oral_history_chunk, oral_history_content: work.oral_history_content, speakers: ["SMITH", "JONES"], text: "Chunk 2")}

  let(:interaction) { described_class.new(question: "What are scientists like?", question_embedding: OralHistoryChunk::FAKE_EMBEDDING) }

  describe "render_user_promopt" do
    it "includes formatted chunks" do
      expect(interaction.render_user_prompt([chunk1, chunk2])).to include <<~EOS.strip
       RETRIEVED CONTEXT CHUNKS:
       ------------------------------
       ORAL HISTORY TITLE: Oral history interview with William John Bailey
       CHUNK ID: #{chunk1.id}
       SPEAKERS: SMITH
       PARAGRAPH NUMBERS: 12, 13, 14, 15
       TEXT:
       #{chunk1.text.chomp}
       ------------------------------
       ORAL HISTORY TITLE: Oral history interview with William John Bailey
       CHUNK ID: #{chunk2.id}
       SPEAKERS: SMITH, JONES
       PARAGRAPH NUMBERS: 12, 13, 14, 15
       TEXT:
       #{chunk2.text.chomp}
       ------------------------------
      EOS
    end
  end

  describe "interaction with claude" do
    before do
      allow(OralHistoryChunk).to receive(:get_openai_embeddings) { |*args| [OralHistoryChunk::FAKE_EMBEDDING] * args.count }
    end

    # AWS sdk returns OpenStruct, we don't want to talk to it, so we mock it here, tests
    # fragile on this being consistent.
    let(:response) do
      claude_mock_response(json_return: json_return)
    end

    before do
      # we aren't testing much with the mock, but oh well
      allow(described_class::AWS_BEDROCK_CLIENT).to receive(:converse).and_return(response)
    end

    let(:json_return) {
      # we're only passing it through, it doesn't matter
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
        "more_chunks_needed" => false,
        "answer_unavailable" => false
      }
    }

    describe "#get_answer" do
      it "returns json answer" do
        answer = interaction.get_answer
        expect(answer).to be_kind_of(Hash)
        expect(answer).to eq json_return
      end
    end

    describe "#get_response" do
      it "fetches chunks, returns response" do
        expect(interaction).to receive(:get_chunks).and_call_original

        response = interaction.get_response

        expect(response).to be_kind_of(OpenStruct) # what AWS sdk returns
      end

      describe "with conversation_record:" do
        let(:ai_conversation) { OralHistory::AiConversation.build(question: "i wonder", question_embedding: OralHistoryChunk::FAKE_EMBEDDING) }

        it "fills out metadata in conversation" do
          chunk1; chunk2

          interaction.get_response(conversation_record: ai_conversation)

          # Doesn't save it
          expect(ai_conversation).not_to be_persisted

          expect(ai_conversation.request_sent_at).to be_present

          expect(ai_conversation.chunks_used).to be_present
          expect(ai_conversation.chunks_used).to all satisfy { |retrieved_chunk_info|
            retrieved_chunk_info.kind_of?(Hash) &&
            retrieved_chunk_info['rank'].present? &&
            retrieved_chunk_info['chunk_id'].present? &&
            retrieved_chunk_info['cosine_distance'].present?
          }

          expect(ai_conversation.response_metadata["usage"]).to be_present
          expect(ai_conversation.response_metadata["metrics"]).to be_present
        end
      end
    end

    describe "#extract_answer" do
      it "extracts answer" do
        answer = interaction.extract_answer(response)
        expect(answer).to eq json_return
      end

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
            answer = interaction.extract_answer(response)
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
            answer = interaction.extract_answer(response)
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
            answer = interaction.extract_answer(response)
          }.to raise_error(described_class::OutputFormattingError)
        end
      end
    end
  end
end
