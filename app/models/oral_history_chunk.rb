# Chunks of text for LLM RAG research
class OralHistoryChunk < ApplicationRecord
  # For testing or what have you, since `embedding` attribute is required.
  # 3072 is size of OpenAI text-embedding-3-large we use
  FAKE_EMBEDDING = [0.0] * 3072

  # from neighbors gem for pg_vector embeddings
  has_neighbors :embedding

  belongs_to :oral_history_content
end
