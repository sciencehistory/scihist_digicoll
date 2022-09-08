require 'rails_helper'
describe MoreLikeThisGetter,  solr: true, indexable_callbacks: true, queue_adapter: :inline do
  let(:getter) {MoreLikeThisGetter.new(work_to_match)}
  let(:work_to_match)   { create(:public_work)  }
  let(:three_public_works) { [
      create(:public_work),
      create(:public_work),
      create(:public_work),
    ]
  }
  let(:three_private_works) { [
      create(:private_work),
      create(:private_work),
      create(:private_work),
    ]
  }
  let! (:indexed_works) {[work_to_match] + three_public_works + three_private_works }

  it "correctly retrieves only the public works" do
    allow(getter).to receive(:mlt_params).and_return({
      "q"         => "id:#{work_to_match.friendlier_id}",
      "mlt.fl"    => 'more_like_this_keywords_tsimv,more_like_this_fulltext_tsimv',
      # We need to override the Minimum Term Frequency and
      # Minimum Document Frequency (we leave it to the default in dev and prod)
      "mlt.mintf"    => '0',
      "mlt.mindf"    => '0',
    })

    expect(getter.works.count).to eq 3
    expect(getter.works.all? {|w| w.published?}).to be true
    expect(getter.works.include? work_to_match).to be false
  end

  it "correctly orders items returned by solr" do
    # This test bypasses SOLR; this is just to ascertain the works are returned
    # in the order SOLR gives them back to us, 
    # not the (arbitrary) order the database gives them to us.
    ids_in_order_of_similarity = three_public_works.map(&:friendlier_id)
    allow(getter).to receive(:friendlier_ids).and_return ids_in_order_of_similarity
    expect(getter.works.map {|w| w.friendlier_id}).to eq ids_in_order_of_similarity
  end
end
