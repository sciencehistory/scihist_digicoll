require 'rails_helper'
describe MoreLikeThisGetter,  solr: true, indexable_callbacks: true, queue_adapter: :inline do
  let(:getter) {MoreLikeThisGetter.new(work_to_match)}
  let(:getter_with_only_three_works) {MoreLikeThisGetter.new(work_to_match, max_works: 3)}
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


  # it "can limit the number of works returned" do
  #   ids_in_order_of_similarity = five_public_works.map(&:friendlier_id)
  #   allow(getter_with_only_three_works).to receive(:friendlier_ids).and_return ids_in_order_of_similarity
  #   expect(getter_with_only_three_works.works.map {|w| w.friendlier_id}).to eq ids_in_order_of_similarity[0..2]
  # end

  it "correctly handles and logs an RSolr::Error::ConnectionRefused from rsolr" do
   allow(getter).to receive(:solr_connection).and_raise(RSolr::Error::ConnectionRefused)
   expect(getter.works).to eq []
  end

  it "correctly retrieves only the public works" do
    allow(getter).to receive(:mlt_params).and_return({
      "q"         => "id:#{work_to_match.friendlier_id}",
      "mlt.fl"    => 'more_like_this_keywords_tsimv,more_like_this_fulltext_tsimv',
      # We need to override the Minimum Term Frequency and
      # Minimum Document Frequency (we leave it to the default in dev and prod)
      "mlt.mintf"    => '0',
      "mlt.mindf"    => '0',
    })

    # debugging URL to check:
    #    "#{ScihistDigicoll::Env.lookup!(:solr_url)}/mlt?wt=json&q=id:#{work_to_match.friendlier_id}" +
    #    "&mlt.fl=more_like_this_keywords_tsimv&mlt.mintf=0&mlt.mindf=0"
    
    expect(getter.works.count).to eq 5
    expect(getter.works.all? {|w| w.published?}).to be true
    expect(getter.works.include? work_to_match).to be false
  end

  it "correctly orders items returned by solr" do
    ids_in_order_of_similarity = five_public_works.map(&:friendlier_id)
    allow(getter).to receive(:friendlier_ids).and_return ids_in_order_of_similarity
    expect(getter.works.map {|w| w.friendlier_id}).to eq ids_in_order_of_similarity
  end

  it "correctly handles and logs an RSolr::Error::ConnectionRefused from rsolr" do
    allow(getter).to receive(:solr_connection).and_return(nil)
    expect(getter.more_like_this_doc_set).to eq []
  end

  it "fails gracefully if the solr connection isn't available" do
    allow(getter).to receive(:solr_connection).and_return(nil)
    expect(getter.more_like_this_doc_set).to eq []
  end

end
