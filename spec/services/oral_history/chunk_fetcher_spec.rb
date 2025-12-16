require 'rails_helper'

describe OralHistory::ChunkFetcher do
  # These are all arbitrary, we just took some random sample vectors, having them
  # not be all zero gives us more realistic data, give us a prefix, we'll pad
  # with zeroes to correct length.
  def fake_vector(*prefix)
    prefix + ([0.0] * (OralHistoryChunk::FAKE_EMBEDDING.length - prefix.length))
  end

  let(:fake_question_embedding) { fake_vector(0.03263719,-0.021255592,-0.018256947,0.012259656,0.008308401)}


  let(:work) { create(:oral_history_work) }

  let!(:chunk1) { create(:oral_history_chunk,
                  embedding: fake_vector(0.01759516,-0.0453438, -0.029577527, -0.032289326, 0.012045433),
                  oral_history_content: work.oral_history_content, speakers: ["SMITH"])}

  let!(:chunk2) { create(:oral_history_chunk,
                        embedding: fake_vector(0.059072047,-0.021131188,-0.013840758,-0.0077753244,-0.02725617),
                        oral_history_content: work.oral_history_content, speakers: ["SMITH", "JONES"], text: "Chunk 2")}

  let!(:chunk3) { create(:oral_history_chunk,
                        embedding: fake_vector(0.015151533,-0.01646033,-0.021422518,-0.024602171,0.009659404),
                        oral_history_content: work.oral_history_content, speakers: ["SMITH", "JONES"], text: "Chunk 3")}

  it "fetches" do
    results = described_class.new(question_embedding: fake_question_embedding, top_k: 2).fetch_chunks

    expect(results.length).to be 2
    expect(results).to all be_kind_of(OralHistoryChunk)
    expect(results).to all satisfy { |r| r.neighbor_distance.present? }

    # make sure we can follow associations without triggering strict loading error
    results.collect(&:oral_history_content).flatten.collect(&:work)
  end
end
