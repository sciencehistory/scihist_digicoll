require 'rails_helper'

DBQueryMatchers.configure do |config|
  config.schemaless = true
end

describe ReindexWorksJob do
  let(:work_ids) { [create(:work), create(:work)].collect(&:id) }

  let(:solr_update_url_regex) { /^#{Regexp.escape(ScihistDigicoll::Env.lookup!(:solr_url) + "/update/json")}/ }

  before do
    stub_request(:any, solr_update_url_regex)
  end

  it "reindexes in a batch" do
    ReindexWorksJob.new(work_ids).perform_now

    expect(WebMock).to have_requested(:post, solr_update_url_regex).once
  end

  it "skips missing IDs without error" do
    ReindexWorksJob.new([SecureRandom.uuid, SecureRandom.uuid]).perform_now

    expect(WebMock).not_to have_requested(:post, solr_update_url_regex)
  end
end
