module OralHistory
  # finds chunks, builds prompt, sends to claude, gets answer.
  #
  # Can re-try with more chunks when Claude asks for it, as instructed.
  #
  # Uses Claude Sonnet via AWS bedrock.
  #
  # Does not do a continuous conversation, user gets one isolated question. Returns
  # answer as JSON.
  class ClaudeInteractor
    # claude sonnet 4.5
    MODEL_ID = "global.anthropic.claude-sonnet-4-5-20250929-v1:0"

    INITIAL_CHUNK_COUNT = 8

    ANSWER_UNAVAILABLE_TEXT = "I cannot answer this question from the material available."

    # should e threadsafe, and better to re-use for re-used connections maybe
    AWS_BEDROCK_CLIENT = Aws::BedrockRuntime::Client.new(
      access_key_id:      ScihistDigicoll::Env.lookup(:aws_access_key_id),
      secret_access_key:  ScihistDigicoll::Env.lookup(:aws_secret_access_key),
      region:             ScihistDigicoll::Env.lookup(:aws_region)
    )

    attr_reader :question, :question_embedding

    def initialize(question:, question_embedding:)
      @question = question
      @question_embedding = question_embedding
    end

    # convenience to look up the embedding
    def self.with_question(question)
      self.new(question: question, question_embedding: OralHistoryChunk.get_openai_embedding(question))
    end

    # Convenience method for back-end tests. Contacts Claude via API to get an answer.
    #
    # @return [Hash] json hash with narrative and footnotes keys.
    def get_answer
      extract_answer( get_response )
    end

    # Takes AWS Bedrock Claude response, gets and validates our JSON answer from it
    #
    # Can raise an OralHistory::ClaudeInteractor::OutputFormattingError
    def extract_answer(response)
      raw_text = response.output.message.content.first.text

      # Claude is insisting on including a markdown fence, remove it
      raw_text.gsub!(/(\A\s*```json)|(```\s*\Z)/, '')

      # raise if we're not validated
      return validated_claude_response( JSON.parse(raw_text) )
    rescue JSON::ParserError => e
      raise OutputFormattingError.new("Does not parse as JSON: #{e.message};\n\n\n#{raw_text}\n\n" , output: raw_text)
    end

    # @param converesation_record [OralHistory::AiConversation] optiona, if given we'll log
    #   parts of our interaction there.
    #
    # @return [OpenStruct] from the AWS bedrock client
    #
    # can raise a Aws::Errors::ServiceError
    def get_response(conversation_record:nil)
      chunks = get_chunks(k: INITIAL_CHUNK_COUNT)

      conversation_record&.record_chunks_used(chunks)

      user_instructions = construct_user_prompt(chunks)

      conversation_record&.request_sent_at = Time.current

      # more params are available, both general bedrock and specific to model
      response = AWS_BEDROCK_CLIENT.converse(
        model_id: MODEL_ID,
        system: [{ text: system_instructions }],
        messages: [{ role: 'user', content: [{ text: user_instructions }] }]
      )

      # store certain parts of response as metrics

      conversation_record&.response_metadata = {
        "usage" => response.usage.to_h,
        "metrics" => response.metrics.to_h
      }

      return response
    end

    def system_instructions
      # - If fewer than 5 unique oral histories are represented in the supplied chunks, and the question is broad or asks about multiple individuals, set "more_chunks_needed": true.
      # - Write the answer as if you have complete knowledge, without mentioning the source or process of retrieval.
      # - If more information is needed to answer the full question, mark more_chunks_needed.
      <<~EOS
        You are an expert research assistant specialized in analyzing long oral-history interview transcripts. Follow these rules carefully. Adherence is mandatory.

        ## RULES

        [NARRATIVE RULES]
        - Write a concise readable, coherent narrative answer for end-users.
        - If you mention a person in an answer, always give their name, never just a role, description, pronoun, or relationship.
        - Only use evidence from the retrieved chunks. Never hallucinate or speculate or use outside information.
        - Reason internally, but do NOT show intermediate reasoning.
        - If the claim cannot be supported by the provided evidence, set "answer_unavailable": true in the JSON, and set narrative to "#{ANSWER_UNAVAILABLE_TEXT}"
        - Integrate claims from the retrieved chunks with inline footnote numbers [^1], [^2], etc. Only use each footnote once.
        - Inline footnotes must correspond exactly to the footnotes included.
        - Do NOT include disclaimers about retrieval, missing evidence, or limitations.
        - Do NOT mention or imply anything about chunks, retrieved material, context, corpus coverage, or what is not found.
        - Never mention or refer to: "chunks", "snippets", "passages", "portions", "retrieved" anything, or similar technical details of the storage or retrieval process.

        [MORE CHUNKS RULE]
        - If fewer than 3 unique oral histories are represented in the supplied chunks, and the question is broad or asks about multiple individuals, set "more_chunks_needed": true.
        - For questions asking about all scientists, any scientists, groups, long time periods, or the whole collection, default to "more_chunks_needed": true unless evidence clearly covers the question.
        - Otherwise, determine if the question can be fully answered from the supplied evidence and set "more_chunks_needed" accordingly.
        - Never mention "more chunks" in the narrative; only reflect it in the JSON key.

        [FOOTNOTE RULES]
        - Every factual statement must have a footnote citing the exact paragraph(s) that support it.
        - Chunks may contain multiple paragraphs; always cite the specific supporting paragraph numbers, not the whole chunk unless necessary.
        - Every footnote should have one direct quote excerpted from the cited evidence, as a short represetative example of evidence. It should
          be between 30 and 50 words.
        - The quote must come directly from the cited paragraph(s); do not paraphrase.

        [JSON OUTPUT RULES]
        - JSON structure:

        {
          "narrative": "<full readable answer>",
          "footnotes": [
            {
              "number": 1,
              "chunk_id": "<chunk_id>",
              "oral_history_title": "<oral_history_title>",
              "paragraph_start": <number>,
              "paragraph_end": <number>,
              "quote": "<≤50-word excerpt>"
            }
          ],
          "more_chunks_needed": true | false,
          "answer_unavailable": true | false
        }

        - Output a single valid JSON object ONLY.
        - Do NOT include narrative, explanations, summaries, or code fences outside the JSON.
        - The "narrative" field inside the JSON contains the full readable answer.
        - Do NOT output any text before or after the JSON object.

        [SELF-CHECK RULES]
        - Before returning JSON, verify all rules are followed.
        - Ensure all required footnote keys are present and correctly spelled.
        - Ensure narrative does not contain forbidden phrases: "chunk", "retrieved material", "context", "corpus", "based on the retrieved context", "available evidence", "no other interviews", "not found", "the model", "AI", "as an AI", "the system", "limitations".
        - If any rule is violated, revise the answer before outputting JSON.
        - If any text appears outside the JSON object, revise the output so that only a single JSON object is returned.
      EOS
    end

    def construct_user_prompt(chunks)
      <<~EOS
        USER QUESTION:
        #{question}

        RETRIEVED CONTEXT CHUNKS:
        #{format_chunks chunks}

        TASK:

        - Provide the concise readable narrative **inside the JSON field "narrative" only**.
        - The narrative should only use the text in the supplied chunks to answer the question.
        - The narrative should include inline citations matching the footnotes ([^1], [^2], etc.).
        - Footnotes must follow the JSON structure specified in the system prompt.
      EOS
    end

    # @param k [Integer] how many chunks to get
    def get_chunks(k: INITIAL_CHUNK_COUNT)
      # TODO: the SQL log for the neighbor query is too huge!!
      # Preload work, so we can get title or other metadata we might want.
      OralHistoryChunk.neighbors_for_embedding(question_embedding).limit(k).includes(oral_history_content: :work).strict_loading
    end

    def format_chunks(chunks)
      separator = "------------------------------"

      chunks.collect do |chunk|
        # Title is really just for debugging, it can always be fetched by chunk_id, but
        # it does make debugging a lot easier to keep the title in the pipeline, to
        # footnote.

        title = chunk.oral_history_content.work.title

        # hackily get a date range
        dates = chunk.oral_history_content.work.date_of_work.collect { |d| [d.start, d.finish]}.
          flatten.collect(&:presence).compact.uniq.sort

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

    # The thing we asked Claude for, does it look like we asked?
    #
    # Raises ClaudeInteractor::OutputFormattingError if not
    #
    # @return [Hash] arg passed in, for convenient chaining
    def validated_claude_response(json)
      unless json.kind_of?(Hash)
        raise OutputFormattingError.new("not a hash", output: json)
      end

      required_top_keys = %w[narrative footnotes more_chunks_needed answer_unavailable]
      required_footnote_keys = %w[number oral_history_title chunk_id paragraph_start paragraph_end quote]

      missing_top = required_top_keys - json.keys
      if missing_top.any?
        raise OutputFormattingError.new("Missing top-level keys: #{missing_top.join(', ')}", output: json)
      end

      json['footnotes'].each_with_index do |footnote, i|
        missing_fn_keys = required_footnote_keys - footnote.keys
        if missing_fn_keys.any?
          raise OutputFormattingError.new("Missing keys in footnote #{i+1}: #{missing_fn_keys.join(', ')}", output: json)
        end
      end

      # check all footnotes are present in both directions
      footnote_refs = json["narrative"].scan(/\[\^(\d+)\]/).flatten.collect(&:to_i)
      footnotes = json["footnotes"].collect { |h| h["number"] }
      footnote_refs.zip(footnotes) do |pair|
        unless pair.first == pair.second
          raise OutputFormattingError.new("Footnotes don't match up at note: #{pair}", output: json)
        end
      end

      json
    end

    # we asked Claude for json in a certain format, did we get it?
    class OutputFormattingError < StandardError
      attr_reader :output
      def initialize(msg=nil, output: nil)
        @output = output
        super(msg)
      end
    end
  end
end
