require 'rails_helper'
describe MoreLikeThisGetter,  solr: true, indexable_callbacks: true, queue_adapter: :inline do

  let(:shared_subject)  { "aaa" }

  let(:getter) {MoreLikeThisGetter.new(work_to_match, limit: limit)}
  let(:work_to_match)   { create(:public_work, subject: shared_subject, description: shared_subject)  }

  let(:five_public_works) { [
      create(:public_work, subject: shared_subject, description: shared_subject),
      create(:public_work, subject: shared_subject, description: shared_subject),
      create(:public_work, subject: shared_subject, description: shared_subject),
      create(:public_work, subject: shared_subject, description: shared_subject),
      create(:public_work, subject: shared_subject, description: shared_subject)
    ]
  }

  let! (:indexed_works) { [work_to_match] + five_public_works }

  # The first example always works.
  # Comment it out and the second example works.
  context "limit to 2" do
    let(:limit) { 2 }
    it "returns 2 works" do
      # Make sure this is not using the Rails cache.
      expect(ScihistDigicoll::Env.lookup(:cache_more_like_this)).to eq false
      expect(getter.works.count).to eq 2
    end
  end

  # We need some way to either disable SOLR's document cache,
  # or to clear it between these two examples.
  
  context "default limit, which is 5" do
    let(:limit) { 5 }
    it "returns 5 works" do
      expect(ScihistDigicoll::Env.lookup(:cache_more_like_this)).to eq false
      expect(getter.works.count).to eq 5
    end
  end
end
