require 'rails_helper'
# NOTE:
# helpful SOLR console debugging URL:
#    "#{ScihistDigicoll::Env.lookup!(:solr_url)}/mlt?wt=json&q=id:#{work_to_match.friendlier_id}" +
#    "&mlt.fl=more_like_this_keywords_tsimv&mlt.mintf=0&mlt.mindf=0&rows=7"
#
describe MoreLikeThisGetter,  solr: true, indexable_callbacks: true, queue_adapter: :inline do
  let(:getter) {MoreLikeThisGetter.new(work_to_match)}
  let(:other_getter) {MoreLikeThisGetter.new(work_to_match)}

  let(:getter_of_two_works) {MoreLikeThisGetter.new(work_to_match, max_number_of_works: 2)}
  let(:work_to_match)   { create(:public_work, subject: "aaa", description: "aaa")  }
  let(:five_public_works) { [
      create(:public_work, subject: "aaa", description: "aaa"),
      create(:public_work, subject: "aaa", description: "aaa"),
      create(:public_work, subject: "aaa", description: "aaa"),
      create(:public_work, subject: "aaa", description: "aaa"),
      create(:public_work, subject: "aaa", description: "aaa"),
    ]
  }
  
  let(:five_private_works) { [
      create(:private_work, subject: "aaa", description: "aaa"),
      create(:private_work, subject: "aaa", description: "aaa"),
      create(:private_work, subject: "aaa", description: "aaa"),
      create(:private_work, subject: "aaa", description: "aaa"),
      create(:private_work, subject: "aaa", description: "aaa"),
    ]
  }
  let! (:indexed_works) { [work_to_match] + five_public_works + five_private_works }

  context "calls to test solr" do
    it "can limit the number of works returned" do
      expect(getter_of_two_works.works).to eq five_public_works[0..1]
    end

    it "retrieves only public works" do
      expect(getter.works.count).to eq 5
      expect(getter.works.all? {|w| w.published?}).to be true
      expect(getter.works.include? work_to_match).to be false
    end
  end

  it "delivers works in the same order their ids arrived from solr" do
    ids_in_order_of_similarity = five_public_works.map(&:friendlier_id)
    allow(getter).to receive(:friendlier_ids).and_return ids_in_order_of_similarity
    expect(getter.works).to eq five_public_works
  end

  it "fails gracefully if the solr connection isn't available" do
    allow(getter).to receive(:solr_connection).and_return(nil)
    expect(getter.more_like_this_doc_set).to eq []
  end

  it "recovers from a solr error and logs the error" do
    expect(Rails.logger).to receive(:error).with(/RSolr::Error::Http .* #{work_to_match.friendlier_id}/)
    allow(getter).to receive(:solr_connection).and_raise(RSolr::Error::Http.new({},nil))
    expect(getter.works).to eq []
  end

end