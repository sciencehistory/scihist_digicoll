# Chunks of text for LLM RAG research
class OralHistoryChunk < ApplicationRecord
  # from neighbors gem for pg_vector embeddings
  has_neighbors :embedding

  belongs_to :oral_history_content
end
