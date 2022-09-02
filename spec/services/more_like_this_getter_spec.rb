require 'rails_helper'
# Testing the SOLR part of this is slow -- and a pain --
# so we are short-circuiting that part of the code.
describe MoreLikeThisGetter do
  let(:work_to_match)   { create(:public_work)  }
  let(:getter) {MoreLikeThisGetter.new(work_to_match) }
  let(:three_public_work_ids) { [1,2,3].map {create(:public_work).friendlier_id } }
  let(:matching_work_ids) { three_public_work_ids + [create(:private_work).friendlier_id]} 

  it "returns only published works; displays them in order" do
    allow(getter).to receive(:friendlier_ids).and_return(matching_work_ids)
    expect(getter.works.map {|w| w.friendlier_id}).to eq (matching_work_ids[0..2])
  end
end
