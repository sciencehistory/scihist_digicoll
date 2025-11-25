module OralHistory
  # finds chunks, builds prompt, sends to claude, gets answer.
  #
  # Can re-try with more chunks when Claude asks for it, as instructed.
  #
  # Uses Claude Sonnet via AWS bedrock.
  #
  # Does not do a continuous conversation, user gets one isolated question. Returns
  # answer as JSON.
  class ClaudeInteraction
    # claude sonnet 4.5
    MODEL_ID = "global.anthropic.claude-sonnet-4-5-20250929-v1:0"

    INITIAL_CHUNK_COUNT = 8

    # should e threadsafe, and better to re-use for re-used connections maybe
    AWS_BEDROCK_CLIENT = Aws::BedrockRuntime::Client.new(
      access_key_id:      ScihistDigicoll::Env.lookup(:aws_access_key_id),
      secret_access_key:  ScihistDigicoll::Env.lookup(:aws_secret_access_key),
      region:             ScihistDigicoll::Env.lookup(:aws_region)
    )

    attr_reader :question

    def initialize(question: question)
      @question = question
    end

    # Contacts Claude via API to get an answer.
    #
    # @return [Hash] json hash with narrative and footnotes keys.
    def get_answer
      chunks = get_chunks(k: INITIAL_CHUNK_COUNT)
      user_instructions = construct_user_prompt(chunks)

      # more params are available, both general bedrock and specific to model
      response = AWS_BEDROCK_CLIENT.converse(
        model_id: MODEL_ID,
        system: [{ text: system_instructions }],
        messages: [{ role: 'user', content: [{ text: user_instructions }] }]
      )

      raw_text = response.output.message.content.first.text

      # Claude is insisting on including a markdown fence
      raw_text.gsub!(/(\A\s*```json)|(```\s*\Z)/, '')

      return JSON.parse(raw_text)
    end


    def system_instructions
      # - Write the answer as if you have complete knowledge, without mentioning the source or process of retrieval.
      # - If more information is needed to answer the full question, mark more_chunks_needed.
      <<~EOS
        You are an expert research assistant specialized in analyzing long oral-history interview transcripts.

        Your task is to answer the user's question using only the retrieved chunks.

        ## RULES

        - Write a concise, readable, natural narrative answer.
        - If you mention a person in an answer, always give their name, never just a role, description, pronoun, or relationship.
        - Reason internally, but DO NOT show intermediate reasoning.
        - Do NOT state or imply that information is absent from other interviews, documents, or sources.
        - Do NOT mention or imply what is not present in the retrieved chunks, material, text, passages, or any portion of the collection.
        - Do NOT make statements like:
          - "The interviews do not provide information..."
          - "...not available in retrieved context..."
          - "No other interview subjects..."
          - "The retrieved material does not identify…"
        - Integrate claims from the retrieved chunks with inline footnote numbers [1], [2], etc.
        - Inline footnotes must correspond exactly to the footnotes included.
        - Chunks may contain multiple paragraphs; whenever possible, cite the specific paragraph(s) that support a claim, not just the chunk range.
        - Only use evidence from the retrieved chunks. Never hallucinate or speculate or use outside information.
        - The narrative and footnotes must never mention or refer to: "chunks", "snippets", "passages", "portions", "retrieved" anything, or similar technical details of the storage or retrieval process.

        After composing your narrative and footnotes, check all rules listed above.
        - If any rule has been violated, revise your answer to fully comply.
        - Remove any forbidden phrases or metacommentary.
        - Ensure the JSON output is strictly valid and parsable.

        ## OUTPUT FORMAT

        Produce the **entire response as a single JSON object** with this structure:

        {
          "narrative": "<text answer>",
          "footnotes": [
            {
              "number": 1,
              "oral_history_title": "<oral_history_title>",
              "chunk_id": "<chunk_id>",
              "paragraph_start": <number>,
              "paragraph_end": <number>,
              "type": "quote | summary",
              "text": "<text from chunk>"
            },
            ...
          ],
          "more_chunks_needed": true | false,
          "answer_unavailable": true | false
        }

        ### Rules for Json:

        -  Only output a single valid JSON object that is syntactically valid and parseable.
        - `narrative` contains the readable answer.
        - `footnotes` array contains all citations referenced in the narrative, with quote or concise summary of the evidence. The quote or summary should be no more than 50 words or two sentances.
        - `type` = "quote" if complete footnote text is verbatim, "summary" if providing your own summary.
        - `paragraph_start` = `paragraph_end` if citing a single paragraph.
        - `more_chunks_needed` = true if the retrieved chunks do not provide sufficient coverage; false otherwise.
        - If the question can not be answered from the evidence, do not include a narrative, do not include footnotes, but
          set`answer_unavailable` = true
      EOS
    end

    def construct_user_prompt(chunks)
      <<~EOS
        USER QUESTION:
        #{question}

        RETRIEVED CONTEXT CHUNKS:
        #{format_chunks chunks}

        TASK:
        - Write a concise and readable narrative answer using only material from retrieved chunks.
        - You can use material in chunks that is not in the citation text.
        - Generate a JSON object following the system instructions.
      EOS
    end

    # @param k [Integer] how many chunks to get
    def get_chunks(k: INITIAL_CHUNK_COUNT)
      # TODO: the SQL log for the neighbor query is too huge!!
      # Preload work, so we can get title or other metadata we might want.
      OralHistoryChunk.neighbors_for_query(question).limit(k).includes(oral_history_content: :work).strict_loading
    end

    def format_chunks(chunks)
      separator = "------------------------------"

      chunks.collect do |chunk|
        # Title is really just for debugging, it can always be fetched by chunk_id, but
        # it does make debugging a lot easier to keep the title in the pipeline, to
        # footnote.

        title = chunk.oral_history_content.work.title

        # hackily get a date range
        dates = chunk.oral_history_content.work.date_of_work.collect { |d| [d.start, d.finish]}.flatten.compact.uniq.sort
        date_string = if dates.length > 1
          ", #{dates.first.slice(0, 4)}-#{dates.last.slice(0, 4)}"
        elsif dates.length > 0
          ", #{dates.first.slice(0, 4)}"
        else
          ""
        end

        title = title += date_string

        <<~EOS
          #{separator}
          ORAL HISTORY TITLE: #{title}
          CHUNK ID: #{chunk.id}
          SPEAKERS: #{chunk.speakers.join(", ")}
          PARAGRAPH NUMBERS: #{chunk.start_paragraph_number.upto(chunk.end_paragraph_number).to_a.join(", ")}
          TEXT:
          #{chunk.text.chomp}
        EOS
      end.join + "#{separator}"
    end
  end
end
