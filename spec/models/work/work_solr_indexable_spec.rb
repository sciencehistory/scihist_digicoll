require 'rails_helper'

# Mostly we trust Kithe::Indexable to work, but let's do a basic smoke test
describe "Work auto-indexes in Solr with kithe", indexable_callbacks: true do
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
end
