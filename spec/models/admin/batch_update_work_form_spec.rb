require 'rails_helper'

describe Admin::BatchUpdateWorkForm, queue_adapter: :test do
  describe "#update_works" do
    let(:new_additional_title) { "New Title"}
    let(:subject) { described_class.new(:additional_title => [new_additional_title])}
    let(:works) { [create(:work, additional_title: "Old title"), create(:work, additional_title: "Old title")] }

    let(:solr_update_url_regex) { /^#{Regexp.escape(ScihistDigicoll::Env.lookup!(:solr_url) + "/update/json")}/ }

    it "updates values by appending" do
      subject.update_works(works)
      works.each do |w|
        expect(w.reload.additional_title).to eq ["Old title", "New Title"]
      end
    end

    it "queues Solr index update for bg job" do
      stub_request(:any, solr_update_url_regex)

      subject.update_works(works)

      expect(ReindexWorksJob).to have_been_enqueued.with(works.collect(&:id))

      expect(WebMock).not_to have_requested(:post, solr_update_url_regex)
    end
  end

end
