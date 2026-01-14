require 'rails_helper'

RSpec.describe OralHistory::AiConversation, type: :model do
  include AwsBedrockClaudeMockResponse

  describe "#exec_and_record_interaction" do
    let(:session_id) { "dummy-session-id" }
    let(:question) { "How do we?" }
    let(:conversation) { OralHistory::AiConversation.build(question: question, session_id: session_id) }

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
      claude_mock_response(json_return: json_return)
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

    describe "with SOURCE_VERSION" do
      let(:source_version) { "mock_git_sha" }

      before do
        allow(OralHistoryChunk).to receive(:get_openai_embedding).and_return(OralHistoryChunk::FAKE_EMBEDDING)

        allow(ENV).to receive(:[]).and_call_original # for other ENV
        allow(ENV).to receive(:[]).with("SOURCE_VERSION").and_return(source_version)
      end

      it "is recorded" do
        conversation.exec_and_record_interaction
        expect(conversation.project_source_version).to eq source_version
      end
    end

    describe "with response error" do
      let(:json_return) { "illegal not a hash" }
      let(:conversation) { OralHistory::AiConversation.build(question: question, question_embedding: OralHistoryChunk::FAKE_EMBEDDING) }

      it "stores error state and info" do
        conversation.exec_and_record_interaction

        expect(conversation.changed?).to eq false

        expect(conversation.status).to eq "error"

        expect(conversation.error_info).to be_present
        expect(conversation.error_info["exception_class"]).to eq "OralHistory::ClaudeInteractor::OutputFormattingError"
        expect(conversation.error_info["backtrace"]).to be_kind_of(Array)
      end
    end

    describe "on an already in_process conversation" do
      let(:conversation) { OralHistory::AiConversation.build(status: "in_process", question: question, question_embedding: OralHistoryChunk::FAKE_EMBEDDING) }

      it "refuses to run, raises" do
        expect {
          conversation.exec_and_record_interaction
        }.to raise_error(RuntimeError).with_message("can't exec_and_record_interaction on status in_process")
      end
    end

    describe "preserving serialized chunks" do
      let(:chunks) { [create(:oral_history_chunk, :with_oral_history_content), create(:oral_history_chunk, :with_oral_history_content)] }
      let(:conversation) { OralHistory::AiConversation.new }

      it "preserves and rehydrates" do
        conversation.record_chunks_used(chunks)

        # delete em from DB to make sure we can still rehydrate!
        chunks.each(&:delete)

        rehydrated = conversation.rehydrate_chunks_used!

        expect(rehydrated.length).to eq chunks.length
        expect(rehydrated).to all be_valid
        expect(rehydrated).to all(have_attributes(id: be_present, text: be_present))
      end
    end
  end
end
