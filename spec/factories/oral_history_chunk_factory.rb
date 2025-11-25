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
  end
end
