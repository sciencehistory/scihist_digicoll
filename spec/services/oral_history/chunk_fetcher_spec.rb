require 'rails_helper'
require 'matrix'

describe OralHistory::ChunkFetcher do
  def cosine_similarity(a, b)
    a = Vector[*a]
    b = Vector[*b]
    dot = a.inner_product(b)
    dot / (a.norm * b.norm)
  end


  # These are all arbitrary, we just took some random sample vectors, having them
  # not be all zero gives us more realistic data, give us a prefix, we'll pad
  # with zeroes to correct length.
  def fake_vector(*prefix)
    prefix + ([0.0] * (OralHistoryChunk::FAKE_EMBEDDING.length - prefix.length))
  end

  let(:fake_question_embedding) { fake_vector(0.03263719,-0.021255592,-0.018256947,0.012259656,0.008308401)}


  let(:work1) { create(:oral_history_work) }


  let!(:chunk1) { create(:oral_history_chunk,
                  oral_history_content: work1.oral_history_content,
                  embedding: fake_vector(0.01759516,-0.0453438, -0.029577527, -0.032289326, 0.012045433),
                  speakers: ["SMITH"])}

  let!(:chunk2) { create(:oral_history_chunk,
                        oral_history_content: work1.oral_history_content,
                        embedding: fake_vector(0.059072047,-0.021131188,-0.013840758,-0.0077753244,-0.02725617),
                        speakers: ["SMITH", "JONES"], text: "Chunk 2")}


  let(:work2) { create(:oral_history_work) }


  let!(:chunk3) { create(:oral_history_chunk,
                        oral_history_content: work2.oral_history_content,
                        embedding: fake_vector(0.015151533,-0.01646033,-0.021422518,-0.024602171,0.009659404),
                        speakers: ["SMITH", "JONES"], text: "Chunk 3")}

  let!(:chunk4) { create(:oral_history_chunk,
                        oral_history_content: work2.oral_history_content,
                        embedding: fake_vector(0.013049184,-0.019433592,-0.024848722,-0.010990473,0.024592385),
                        speakers: ["SMITH", "JONES"], text: "Chunk 3")}


  let(:all_chunks) { [chunk1, chunk2, chunk3, chunk4] }

  it "fetches" do
    results = described_class.new(question_embedding: fake_question_embedding, top_k: 2).fetch_chunks

    expect(results.length).to be 2
    expect(results).to all be_kind_of(OralHistoryChunk)
    expect(results).to all satisfy { |r| r.neighbor_distance.present? }

    # make sure we can follow associations without triggering strict loading error
    results.collect(&:oral_history_content).flatten.collect(&:work)
  end

  describe "max_per_interview" do
    it "fetches with limit" do
      # We ask for 3, but can only get 2 because of per-doc limit
      results = described_class.new(question_embedding: fake_question_embedding, top_k: 3, max_per_interview: 1).fetch_chunks

      expect(results.length).to eq 2

      # Two oral_history_content_id's, each with only 1 chunk
      groups = results.group_by {|c| c.oral_history_content_id }
      expect(groups.count).to eq 2
      expect(groups.values).to all satisfy { |v| v.length== 1}

      # included chunks have closer vector distance to question than excluded
      excluded = [chunk1, chunk2, chunk3, chunk4].find_all { |c| ! c.id.in?(results.collect(&:id)) }
      excluded_similarity = excluded.collect {|c| cosine_similarity(c.embedding, fake_question_embedding) }

      included_similarity = results.collect {|c| cosine_similarity(c.embedding, fake_question_embedding) }

      # everything included has more similarity than anything excluded!
      expect(included_similarity.min).to be >= excluded_similarity.max
    end
  end

  describe "exclude_chunks" do
    it "can exclude chunks by id" do
      exclude_chunk_ids = [chunk1, chunk3].collect(&:id)
      results = described_class.new(question_embedding: fake_question_embedding, top_k: 100, exclude_chunks: exclude_chunk_ids).fetch_chunks

      expected_ids = all_chunks.collect(&:id) - exclude_chunk_ids
      expect(results.collect(&:id)).to match_array expected_ids
    end

    it "can exclude chunks by chunk" do
      results = described_class.new(question_embedding: fake_question_embedding, top_k: 100, exclude_chunks: [chunk2, chunk4]).fetch_chunks

      expected_ids = all_chunks.collect(&:id) - [chunk2, chunk4].collect(&:id)
      expect(results.collect(&:id)).to match_array expected_ids
    end
  end

  describe "exclude_interviews" do
    it "can exclude interviews by OralHistoryContent model" do
      results = described_class.new(question_embedding: fake_question_embedding, top_k: 100, exclude_interviews: [work1.oral_history_content]).fetch_chunks

      expect(results.collect(&:oral_history_content_id)).not_to include(work1.oral_history_content.id)
    end
  end
end
