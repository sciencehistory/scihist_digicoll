require 'rails_helper'

describe CollectionsListController do
  describe "department filtering" do
    let!(:archives_collection) { create(:collection, published: true, department: "Archives", title: "Archives collection") }
    let!(:museum_collection) { create(:collection, published: true, department: "Museum", title: "Museum collection") }

    it "filters" do
      get :index, params: { department_filter: "museum" }

      expect(response).to have_http_status(200)
      expect(assigns[:collections].collect(&:friendlier_id)).to include(museum_collection.friendlier_id)
      expect(assigns[:collections].collect(&:friendlier_id)).not_to include(archives_collection.friendlier_id)
    end
  end
end
