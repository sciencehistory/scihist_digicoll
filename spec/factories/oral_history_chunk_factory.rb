FactoryBot.define do

  factory :oral_history_chunk, class: OralHistoryChunk do
    start_paragraph_number { 12 }
    end_paragraph_number { 15 }
    embedding { OralHistoryChunk::FAKE_EMBEDDING }

    text do
      <<~EOS
        BROCK: If you think back to your time together at school, what kind of a student
        was Gordon?

        DUARTE: He was a good student. He has always been a tremendous student. Even in
        grammar school. But, he was a year ahead of me. I wasn't in his class.

        BROCK: I know the two of you were good friends. Were you well-liked? Did you
        have a big group of friends that you did things with?

        DUARTE: There were a few kids like us in town. We more or less all hung out at
        his place. [laughter] We had a free run there of things.
      EOS
    end

    after(:build) do |chunk, evaluator|
      # build timestamp info if it's not there
      unless chunk.other_metadata["timestamps"].present?
        chunk.other_metadata["timestamps"] ||= {}

        current_timestamp = 120
        chunk.start_paragraph_number.upto(chunk.end_paragraph_number) do |par_number|
          chunk.other_metadata["timestamps"][par_number.to_s] = {
            "previous" => chunk.other_metadata["timestamps"].dig((par_number-1).to_s, "included")&.last,
            "included" => [(current_timestamp += 30)]
          }
        end
      end
    end

    trait :with_oral_history_content do
      oral_history_content { build(:oral_history_work).oral_history_content }
    end
  end
end
