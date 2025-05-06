require "rails_helper"

describe Scihist::BlacklightSolrRepository do
  # a way to get a configured repository class...
  let(:repository) do
    Scihist::BlacklightSolrRepository.new(CatalogController.blacklight_config).tap do |repo|
      # if we are testing retries, don't actually wait between them
      repo.zero_interval_retry = true
    end
  end

  # A simple smoke test against live solr hoping to be a basic test that the
  # thing works like a Blacklight::Solr::Repository,  our customization attempt
  # hopefully didn't break it.
  describe "ordinary behavior smoke test", solr: true do
    before do
      create(:public_work).update_index
    end

    it "can return results" do
      response = repository.search
      expect(response).to be_kind_of(Blacklight::Solr::Response)
      expect(response.documents).to be_present
    end
  end

  # We're actually going to use webmock to try to mock some error conditions
  # to actually test retry behavior, not going to use live solr.
  describe "retry behavior", solr:true do
    let(:solr_select_url_regex) { /^#{Regexp.escape(ScihistDigicoll::Env.lookup!(:solr_url) + "/select")}/ }

    describe "with solr 400 response" do
      before do
        stub_request(:any, solr_select_url_regex).to_return(status: 400, body: "error")
      end

      it "does not retry" do
        expect {
          response = repository.search
        }.to raise_error(Blacklight::Exceptions::InvalidRequest)

        expect(WebMock).to have_requested(:any, solr_select_url_regex).once
      end
    end

    describe "with solr 404 response" do
      before do
        stub_request(:any, solr_select_url_regex).to_return(status: 404, body: "error")
      end

      it "retries once" do
        expect {
          response = repository.search
        }.to raise_error(Blacklight::Exceptions::InvalidRequest)

        expect(WebMock).to have_requested(:any, solr_select_url_regex).times(2)
      end

      it "logs retries once" do
        logged = []
        allow(Rails.logger).to receive(:warn) do |log_str|
          logged << log_str
        end

        expect {
          response = repository.search
        }.to raise_error(Blacklight::Exceptions::InvalidRequest)

        expect(logged).to include /\AScihist::BlacklightSolrRepository: Retrying Solr request: HTTP 404: Faraday::ResourceNotFound: retry 1/
        #expect(logged).to include /\AScihist::BlacklightSolrRepository: Retrying Solr request: HTTP 404: Faraday::ResourceNotFound: retry 2/
      end
    end
  end
end
