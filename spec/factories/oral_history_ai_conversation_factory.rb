FactoryBot.define do
  factory :ai_conversation, class: OralHistory::AiConversation do
    question { "How do you do it?" }
    question_embedding { OralHistoryChunk::FAKE_EMBEDDING }

    # Ugh we have all this JSON data embedded in here, it's a pain to mock consistently,
    # which probably isn't a great sign.
    trait :success_with_associations do
      transient do
        # this is expensive, yes, but we need it. need to create cause isn't in
        # a real association, sorry.
        chunks { [create(:oral_history_chunk, :with_oral_history_content)] }
      end

      status { :success }

      answer_json do
        {
         "narrative" => "We do it green [^1]. And we do it blue [^2].",
         "footnotes" =>  [
            {
              "number" => 1,
              "paragraph_start" => 10,
              "paragraph_end" => 10,
              "chunk_id" => "1",
              "quote" => "We liked it green"
            },
            {
              "number" => 2,
              "paragraph_start" => 12,
              "paragraph_end" => 12,
              "chunk_id" => "1",
              "quote" => "We liked it blue"
            }
         ],
         "answer_unavailable" => false,
         "more_chunks" => true
        }
      end

      after(:build) do |conversation, evaluator|
        if evaluator.chunks
          # fix footnotes to refer to actual chunk data
          conversation.answer_json["footnotes"].each_with_index do |footnote, index|
            sample_chunk = evaluator.chunks[index % evaluator.chunks.length]
            sample_chunk_paragraph_num = (sample_chunk.start_paragraph_number..sample_chunk.end_paragraph_number).to_a.sample

            footnote["chunk_id"] = sample_chunk.id
            footnote["paragraph_start"] = sample_chunk_paragraph_num
            footnote["paragraph_end"] = sample_chunk_paragraph_num
          end

          conversation.record_chunks_used(evaluator.chunks)
        end
      end
    end
  end
end
