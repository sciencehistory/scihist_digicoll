require 'rails_helper'
describe "Custom Collection Page Requests", type: :request, solr: true, queue_adapter: :test, indexable_callbacks: true do
  describe "immigrants and innovation" do
    let!(:collection) {
      create(:collection, friendlier_id: ScihistDigicoll::Env.lookup(:immigrants_and_innovation_collection_id))
    }
    it "gets custom controller" do
      get collection_path(collection.friendlier_id)

      expect(controller).to be_instance_of(CollectionShowControllers::ImmigrantsAndInnovationCollectionController)
      expect(response.status).to eq(200)
    end
  end

  describe "oral history" do
    let!(:collection) {
      create(:collection, friendlier_id: ScihistDigicoll::Env.lookup(:oral_history_collection_id))
    }
    it "gets custom controller" do
      get collection_path(collection.friendlier_id)

      expect(controller).to be_instance_of(CollectionShowControllers::OralHistoryCollectionController)
      expect(response.status).to eq(200)
    end
  end

  describe "bredig" do
    let!(:collection) {
      create(:collection, friendlier_id: ScihistDigicoll::Env.lookup(:bredig_collection_id))
    }
    it "gets custom controller" do
      get collection_path(collection.friendlier_id)

      expect(controller).to be_instance_of(CollectionShowControllers::BredigCollectionController)
      expect(response.status).to eq(200)
    end
  end
end
