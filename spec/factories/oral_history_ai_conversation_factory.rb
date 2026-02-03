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
         "introduction" => "Scientists in our collection like many colors",
         "findings" =>  [
            {

              "answer" => "John Smith likes it green",
              "citations" => [
                {
                  "oral_history_title" => "Oral history with John Smith",
                  "paragraph_start" => 10,
                  "paragraph_end" => 10,
                  "chunk_id" => "1",
                  "quote" => "We liked it green"
                }
              ]
            },
            {
              "answer" => "Mary Jones prefers blue",
              "citations" => [
                {
                  "oral_history_title" => "Oral history with Mary Jones",
                  "paragraph_start" => 12,
                  "paragraph_end" => 12,
                  "chunk_id" => "1",
                  "quote" => "We liked it blue"
                }
              ]
            }
         ],
         "answer_unavailable" => false,
        }
      end

      after(:build) do |conversation, evaluator|
        if evaluator.chunks && conversation.answer_json["findings"]
          # fix footnotes to refer to actual chunk data
          conversation.answer_json["findings"].collect {|f| f["citations"]}.flatten.each_with_index do |citation, index|
            sample_chunk = evaluator.chunks[index % evaluator.chunks.length]
            sample_chunk_paragraph_num = (sample_chunk.start_paragraph_number..sample_chunk.end_paragraph_number).to_a.sample

            citation["chunk_id"] = sample_chunk.id
            citation["paragraph_start"] = sample_chunk_paragraph_num
            citation["paragraph_end"] = sample_chunk_paragraph_num
          end

          conversation.record_chunks_used(evaluator.chunks)
        end
      end
    end
  end
end
