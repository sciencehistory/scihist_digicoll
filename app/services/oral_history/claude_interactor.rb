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

    ANSWER_UNAVAILABLE_TEXT = "I am unable to answer this question with the methods and sources available."

    # should e threadsafe, and better to re-use for re-used connections maybe
    AWS_BEDROCK_CLIENT = Aws::BedrockRuntime::Client.new(
      access_key_id:      ScihistDigicoll::Env.lookup(:aws_access_key_id),
      secret_access_key:  ScihistDigicoll::Env.lookup(:aws_secret_access_key),
      region:             ScihistDigicoll::Env.lookup(:aws_region)
    )

    attr_reader :question, :question_embedding, :access_limit

    def initialize(question:, question_embedding:, access_limit: nil)
      @question = question
      @question_embedding = question_embedding
      @access_limit = access_limit

      unless @access_limit.in?(OralHistory::ChunkFetcher::ACCESS_LIMITS)
        raise ArgumentError.new("access_limit is #{access_limit.inspect}, but must be in #{OralHistory::ChunkFetcher::ACCESS_LIMITS.inspect}")
      end
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

    # @param converesation_record [OralHistory::AiConversation] optional, if given we'll log
    #   parts of our interaction there.
    #
    # @return [OpenStruct] from the AWS bedrock client
    #
    # can raise a Aws::Errors::ServiceError
    def get_response(conversation_record:nil)
      chunks = get_chunks(conversation_record: conversation_record)


      conversation_record&.record_chunks_used(chunks)
      conversation_record&.request_sent_at = Time.current

      # more params are available, both general bedrock and specific to model
      response = AWS_BEDROCK_CLIENT.converse(
        model_id: MODEL_ID,
        system: [{ text: render_system_instructions }],
        messages: [{ role: 'user', content: [{ text: render_user_prompt(chunks) }] }]
      )

      conversation_record&.add_timing("LLM response received")

      # store certain parts of response as metrics

      conversation_record&.response_metadata = {
        "usage" => response.usage.to_h,
        "metrics" => response.metrics.to_h
      }

      return response
    end

    # find template in eg  ./claude_interactor/system_instructions.txt.erb
    def render_system_instructions
      # In Rails 8.1, could switch to .md.erb and :md format if we wanted. no real difference.
      ApplicationController.render( template: "claude_interactor/system_instructions",
                                    locals: {
                                      answer_unavailable_text: ANSWER_UNAVAILABLE_TEXT
                                    },
                                    formats: [:text])
    end

    def render_user_prompt(chunks)
      # In Rails 8.1, could switch to .md.erb and :md format if we wanted. no real difference.
      ApplicationController.render( template: "claude_interactor/initial_user_prompt",
                                    locals: {
                                      question: question,
                                      chunks: chunks
                                    },
                                    formats: [:text]
                                  )
    end


    # @param converesation_record [OralHistory::AiConversation] optional, if given we'll log
    #   parts of our interaction there.
    def get_chunks(conversation_record: nil)
      conversation_record&.add_timing("About to fetch chunks")

      # fetch first 8 closest-vector chunks
      chunks = OralHistory::ChunkFetcher.new(question_embedding: question_embedding, top_k: 6, access_limit: access_limit).fetch_chunks

      conversation_record&.add_timing("First chunk fetch complete")

      # now fetch another 8, but only 1-per-interview, not including any interviews from above
      chunks += OralHistory::ChunkFetcher.new(question_embedding: question_embedding,
                                              top_k: 6,
                                              max_per_interview: 1,
                                              exclude_interviews: chunks.collect(&:oral_history_content_id).uniq,
                                              access_limit: access_limit).fetch_chunks

      conversation_record&.add_timing("Second chunk fetch complete")

      chunks
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

      required_top_keys = %w[introduction findings answer_unavailable]
      required_footnote_keys = %w[oral_history_title chunk_id paragraph_start paragraph_end quote]

      missing_top = required_top_keys - json.keys
      if missing_top.any?
        raise OutputFormattingError.new("Missing top-level keys: #{missing_top.join(', ')}", output: json)
      end

      # json['findings'].each_with_index do |finding, i|
      #   missing_fn_keys = required_footnote_keys - footnote.keys
      #   if missing_fn_keys.any?
      #     raise OutputFormattingError.new("Missing keys in footnote #{i+1}: #{missing_fn_keys.join(', ')}", output: json)
      #   end
      # end

      # # check all footnotes are present in both directions
      # footnote_refs = json["narrative"].scan(/\[\^(\d+)\]/).flatten.collect(&:to_i)
      # footnotes = json["footnotes"].collect { |h| h["number"] }
      # unless footnote_refs == footnotes
      #   raise OutputFormattingError.new("Footnotes don't match up at notes #{(footnotes + footnote_refs) - (footnotes & footnote_refs)}", output: json)
      # end

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
