class CreateOralHistoryChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :oral_history_chunks do |t|
      # 3072 is vector size for OpenAI text-embedding-3-large, that we plan to use
      t.vector :embedding, limit: 3072, null: false

      t.references :oral_history_content, foreign_key: { to_table: :oral_history_content }, null: false

      t.integer :start_paragraph_number
      t.integer :end_paragraph_number
      t.text :text
      t.string :speakers, array: true, default: []
      t.jsonb :other_metadata, default: {}

      t.timestamps
    end

    # we will use cosine similarity per ChatGPT advice, let's make an index.
    # text-embedding-3-large's 3072 dimensions is too large for a pg_vector HNSW
    # We can index it with halfvec, not as precise but maybe good enough?
    add_index :oral_history_chunks, "(embedding::halfvec(3072)) halfvec_cosine_ops", using: :hnsw
  end
end
