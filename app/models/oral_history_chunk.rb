# Chunks of text for LLM RAG research
class OralHistoryChunk < ApplicationRecord
  # For testing or what have you, since `embedding` attribute is required.
  # 3072 is size of OpenAI text-embedding-3-large we use
  FAKE_EMBEDDING = [0.0] * 3072

  # should be thread-safe, re-use connections
  OPENAI_CLIENT = OpenAI::Client.new(
    access_token: ScihistDigicoll::Env.lookup("openai_api_key"),
    # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
    log_errors: Rails.env.development?
    #request_timeout: REQUEST_TIMEOUT
  )


  # One or more texts, do one request to OpenAI to get one or more embedding
  # vectors back. Can include multiple texts to do a bulk request for all of them.
  def self.get_openai_embeddings(*texts)
    response = OPENAI_CLIENT.embeddings(
      parameters: {
        model: "text-embedding-3-large",
        input: texts
      }
    )

    if response["error"]
      raise StandardError.new("OpenAI Error: #{response['error']['message']}")
    end

    return response["data"].map { |d| d["embedding"] }
  end

  def self.get_openai_embedding(text)
    self.get_openai_embeddings(text).first
  end

  # note results will have a #neighbor_distance with the cosine distance and/or
  # similarity, not sure about these scores.
  def self.neighbors_for_query(query)
    self.nearest_neighbors(:embedding, get_openai_embedding(query), distance: "cosine")
  end

  # Filter embedding from logs just cause it's so darn long!
  self.filter_attributes += [:embedding]

  # from neighbors gem for pg_vector embeddings
  has_neighbors :embedding

  belongs_to :oral_history_content
end
