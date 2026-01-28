class EmbeddingVectorToHalfvec < ActiveRecord::Migration[8.0]
  disable_ddl_transaction! # for concurrent index creation
                           #
  def change
    reversible do |direction|

      direction.up do
        remove_index :oral_history_chunks, :embedding, if_exists: true

        change_column :oral_history_chunks,
                    :embedding,
                    :halfvec,
                    limit: 3072,
                    using: "embedding::halfvec"

        add_index :oral_history_chunks,
            :embedding,
            using: :hnsw,
            opclass: :halfvec_cosine_ops,
            algorithm: :concurrently

      end

      direction.down do
        remove_index :oral_history_chunks, :embedding, if_exists: true

        change_column :oral_history_chunks,
                    :embedding,
                    :vector,
                    limit: 3072
      end
    end
  end
end
