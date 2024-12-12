require 'rails_helper'

RSpec.describe CollectionShowController, solr: true, indexable_callbacks: true, type: :controller do

  # See https://github.com/sciencehistory/scihist_digicoll/issues/2585
  describe "Basic indexing smoke test" do
    let(:container_info) do
      Work::PhysicalContainer.new({"box"=>"1", "folder"=>"3"})
    end
    let(:work) { create(:work, physical_container: container_info) }
    it "indexes the box and folder" do
      output_hash = WorkIndexer.new.map_record(work)
      expect(output_hash["box_isim"]).to eq ["1"]
      expect(output_hash["folder_isim"]).to eq ["3"]
    end

    describe "more than one box or folder associated with the work" do
      let(:container_info) do
        Work::PhysicalContainer.new({"box"=>"1 - 2", "folder"=>"3 - 4"})
      end
      it "splits multiple boxes / folders into two integers so they can be matched" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["box_isim"]).to eq ["1", "2"]
        expect(output_hash["folder_isim"]).to eq ["3", "4"]
      end
    end
  end


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
    let(:b12f1) {
      Work::PhysicalContainer.new({ "box"=>"12" ,  "folder"=> "1" })
    }
    let!(:works) {
      [
        create(:work, :published, physical_container: b1f1, title: "b1_f1_1", contained_by:   [collection]),
        create(:work, :published, physical_container: b1f1, title: "b1_f1_2", contained_by:   [collection]),
        create(:work, :published, physical_container: b1f2, title: "b1_f1_3", contained_by:   [collection]),
        create(:work, :published, physical_container: b1f2, title: "b12_f1",  contained_by:   [collection]),
      ]
    } 
    let!(:collection) { create(:collection, friendlier_id: "faked", department: "Archives") }

    let(:box_and_folder_params) do
      {"q"=>"", "box_id"=>"1", "folder_id"=>"1", "sort"=>"", "collection_id"=> collection.friendlier_id }
    end


    it "Smoke test: finds works by box and folder" do
      get :index, params: box_and_folder_params
      expect(response).to have_http_status(200)
      expect(response.body).to     include(works[0].title)
      expect(response.body).to     include(works[1].title)
      expect(response.body).not_to include(works[2].title)
      # Box numbers treated like integers, not strings:
      # A search for box "1" should not match box "12"
      expect(response.body).not_to include(works[3].title)
    end

    it "can't search for folder without specifying the containing box" do
      get :index, params: {"q"=>"", "folder_id"=>"1", "sort"=>"", "collection_id"=> collection.friendlier_id }
      expect(response).to have_http_status(200)
      expect(response.body).to include("If you specify a folder, please also specify a box")
    end


  end
end
