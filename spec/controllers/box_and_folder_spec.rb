require 'rails_helper'

RSpec.describe CollectionShowController, solr: true, indexable_callbacks: true, type: :controller do
  describe "two works in a folder" do
    render_views

    let(:box_id) { 1 }
    let(:folder_id) { 1 }
    let(:b1f1) {
      Work::PhysicalContainer.new({ "box"=>box_id ,  "folder"=> folder_id })
    }
    let(:b1f2) {
      Work::PhysicalContainer.new({ "box"=>box_id ,  "folder"=> folder_id + 1 })
    }
    let!(:works) {
      [
        create(:work, :published, physical_container: b1f1, title: "b1_f1_1", contained_by:   [collection]),
        create(:work, :published, physical_container: b1f1, title: "b1_f1_2", contained_by:   [collection]),
        create(:work, :published, physical_container: b1f2, title: "b1_f1_3", contained_by:   [collection]),
      ]
    } 
    let!(:collection) { create(:collection, friendlier_id: "faked") }

    let(:box_and_folder_params) do
      {"q"=>"", "box_id"=>"1", "folder_id"=>"1", "sort"=>"", "collection_id"=> collection.friendlier_id }
    end

    it "redirects to be interprted properly" do
      get :index, params: box_and_folder_params
      expect(response).to have_http_status(200)
      expect(response.body).to     include(works[0].title)
      expect(response.body).to     include(works[1].title)
      expect(response.body).not_to include(works[2].title)
    end
  end
end
