require 'rails_helper'

describe OralHistoryAiConversationJob, type: :job do
  let(:question) { "How do we?" }
  let(:session_id) { "dummy-session-id" }

  it ".launch" do
    record = described_class.launch(question: question, session_id: session_id)

    expect(described_class).to have_been_enqueued

    expect(record).to be_kind_of(OralHistory::AiConversation)
    expect(record.persisted?).to be true
    expect(record.status).to eq "queued"
    expect(record.external_id).to be_present

    expect(record.question).to eq question
    expect(record.session_id).to eq session_id
  end

  describe "#perform" do
    let(:conversation) { OralHistory::AiConversation.create!(question: question, session_id: session_id) }

    describe "with error" do
      let(:error_class) { StandardError }

      before do
        expect(conversation).to receive(:exec_and_record_interaction).and_raise(error_class)
      end

      it "finishes in error state, and raises original" do
        expect {
          described_class.perform_now(conversation)
        }.to raise_error(error_class)

        expect(conversation.status).to eq "error"
        expect(conversation.error_info["exception_class"]).to eq error_class.name
        expect(conversation.changed?).to eq false
      end
    end
  end
end
