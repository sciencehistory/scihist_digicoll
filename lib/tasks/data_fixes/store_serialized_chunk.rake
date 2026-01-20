namespace :scihist do
  namespace :data_fixes do
    desc """
      Takes legacy OralHistory::AiConversation objects that lack fully serialized chunks, and
      adds fully serialized chunks, if they are still present.

      bundle exec rake scihist:data_fixes:store_serialized_chunk
    """

    task :store_serialized_chunk => :environment do
      # still has chunk_id key, legacy
      legacy_ones = OralHistory::AiConversation.where("jsonb_path_exists(chunks_used, '$[*] ? (@.chunk_id != null)')")

      progress_bar = ProgressBar.create(total: legacy_ones.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      fixed = 0
      could_not_fix = 0

      legacy_ones.find_each do |conv|
        begin
          chunk_ids = conv.chunks_used.collect { |h| h["chunk_id"]}

          chunks = OralHistoryChunk.in_order_of(:id, chunk_ids).find(chunk_ids)
          chunks.each(&:readonly!)

          # add in cosine neighbor distance from query that was stored in legacy
          0.upto(conv.chunks_used.count - 1).each do |index|
            chunks[index].neighbor_distance = conv.chunks_used[index]["cosine_distance"]
          end

          conv.record_chunks_used(chunks)
          conv.save!

          fixed += 1
        rescue ActiveRecord::RecordNotFound
          could_not_fix += 1
          progress_bar.log("Could not find chunks for AiConversation #{conv.id}, #{conv.external_id}")
        end

        progress_bar.increment
      end

      puts "Fixed: #{fixed}"
      puts "Could not fix: #{could_not_fix}"
    end
  end
end
