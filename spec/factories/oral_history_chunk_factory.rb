FactoryBot.define do
  factory :oral_history_chunk, class: OralHistoryChunk do
    embedding { OralHistoryChunk::FAKE_EMBEDDING }
  end
end
