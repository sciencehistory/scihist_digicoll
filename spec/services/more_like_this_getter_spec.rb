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

    it "returns only public works" do
      expect(getter.works.count).to eq 5
      expect(getter.works.all? {|w| w.published?}).to be true
      expect(getter.works.include? work_to_match).to be false
    end

  end

  context "caching" do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
    end

    it "doesn't cache by default" do
      expect(Rails.cache.read(work_to_match.friendlier_id, namespace: :more_like_this)).to eq nil
      getter.works
      expect(Rails.cache.read(work_to_match.friendlier_id, namespace: :more_like_this)).to eq nil
    end

    context "setting turned on" do
      before do
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:cache_more_like_this).and_return(true)
      end 

      after do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      end

      it "writes to the cache" do
        expect(Rails.cache.read(work_to_match.friendlier_id, namespace: :more_like_this)).to eq nil
        expect(getter.works.map {|w| w.friendlier_id}).to eq Rails.cache.read(work_to_match.friendlier_id, namespace: :more_like_this)
      end

      it "reads from the cache" do
        expect(Rails.cache.read(work_to_match.friendlier_id)).to eq nil
        Rails.cache.write(work_to_match.friendlier_id, ['a', 'b', 'c'], namespace: :more_like_this)
        expect(getter.friendlier_ids).to eq ['a', 'b', 'c']
      end

      context "a work was unpublished after being cached" do
        it "only returns public works, even if the cache contains private works" do
          Rails.cache.write(work_to_match.friendlier_id, five_private_works.map(&:friendlier_id), namespace: :more_like_this)
          expect(getter.works.length).to eq 0
        end
      end
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