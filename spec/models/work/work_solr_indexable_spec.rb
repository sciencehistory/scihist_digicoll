require 'rails_helper'

# Mostly we trust Kithe::Indexable to work, but let's do a basic smoke test
describe "Work auto-indexes in Solr", indexable_callbacks: true do
  describe "with stubbed solr" do
    let(:update_url) { "#{ScihistDigicoll::Env.lookup!(:solr_url)}/update/json?softCommit=true" }
    before do
      stub_request(:post, update_url)
    end

    it "posts to solr via our indexer on create" do
      work = FactoryBot.build(:work)

      expect(work).to receive(:update_index).and_call_original
      expect(Work.kithe_indexable_mapper).to receive(:process_with).and_call_original

      work.save!

      expect(WebMock).to have_requested(:post, update_url)
    end

    # Make sure that changing the collection triggers a reindex, because we
    # need it to, since we index collection id with work to support search-inside-collection.
    describe "on contained_by change" do
      let(:collection) { FactoryBot.create(:collection)}
      let(:work) { FactoryBot.create(:work) }

      it "reindexes on contained_by change" do
        work.contained_by << collection

        expect(work).to receive(:update_index).and_call_original
        expect(Work.kithe_indexable_mapper).to receive(:process_with).and_call_original

        work.save!
      end

      it "reindexes on contained_by_ids change" do
        work.contained_by_ids << collection.id

        expect(work).to receive(:update_index).and_call_original
        expect(Work.kithe_indexable_mapper).to receive(:process_with).and_call_original

        work.save!
      end

      # This does NOT currently work to trigger reindexing, beware!
      skip "reindexes on collection contains change" do
        collection.contains << work

        expect(work).to receive(:update_index).and_call_original
        expect(Work.kithe_indexable_mapper).to receive(:process_with).and_call_original

        collection.save!
      end
    end
  end

  # mostly to test our real solr integration tests
  describe "with real solr", solr: true do
    it "indexes to real solr" do
      work = FactoryBot.create(:work, title: "to be indexed")
      solr_query_url = "#{ScihistDigicoll::Env.lookup!(:solr_url)}/select?q=id:#{CGI.escape work.friendlier_id}"
      response = Net::HTTP.get_response(URI.parse(solr_query_url))

      solr_docs = JSON.parse(response.body)["response"]["docs"]

      indexed_doc = solr_docs.find { |h| h["id"] == work.friendlier_id }
      expect(indexed_doc).to be_present
    end
  end
end
