require 'rails_helper'

RSpec.describe OralHistory::AiConversation, type: :model do
  describe "#exec_and_record_interaction" do
    let(:session_id) { "dummy-session-id" }
    let(:question) { "How do we?" }
    let(:conversation) { OralHistory::AiConversation.create!(question: question, session_id: session_id) }

     let(:json_return) do
      {
        "narrative" => "This is an answer",
        "footnotes" => [],
        "more_chunks_needed" => false,
        "answer_unavailable" => false
      }
    end

    # AWS sdk returns OpenStruct, we don't want to talk to it, so we mock it here, tests
    # fragile on this being consistent.
    let(:response) do
       OpenStruct.new(
          output: OpenStruct.new(
            message: OpenStruct.new(
              role: "assistant",
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
            ),
            stop_reason: "end_turn",
            usage: OpenStruct.new(
              input_tokens: 7087, output_tokens: 54, total_tokens: 7141, cache_read_input_tokens: 0, cache_write_input_tokens: 0
            ),
            metrics: OpenStruct.new(latency_ms: 3252)
          )
        )
    end

    before do
      # we aren't testing much with the mock, but oh well
      allow(OralHistory::ClaudeInteractor::AWS_BEDROCK_CLIENT).to receive(:converse).and_return(response)
    end

    it "will fill out conversation record" do
      expect(OralHistoryChunk).to receive(:get_openai_embedding).and_return(OralHistoryChunk::FAKE_EMBEDDING)

      conversation.exec_and_record_interaction

      expect(conversation.changed?).to eq false

      expect(conversation.question_embedding).to be_present

      expect(conversation.status).to eq "success"
      expect(conversation.answer_json).to eq json_return
    end

    describe "with response error" do
      let(:json_return) { "illegal not a hash" }
      let(:conversation) { OralHistory::AiConversation.create!(question: question, question_embedding: OralHistoryChunk::FAKE_EMBEDDING) }

      it "stores error state and info" do
        conversation.exec_and_record_interaction

        expect(conversation.changed?).to eq false

        expect(conversation.status).to eq "error"

        expect(conversation.error_info).to be_present
        expect(conversation.error_info["exception_class"]).to eq "OralHistory::ClaudeInteractor::OutputFormattingError"
        expect(conversation.error_info["backtrace"]).to be_kind_of(Array)
      end
    end
  end
end
