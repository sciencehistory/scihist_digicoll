require 'rails_helper'

# mostly we use feature tests, but some things can't easily be tested that way
# Should this be a 'request' spec instead of a rspec 'controller' spec
# (that is a rails 'functional' test)?
RSpec.describe CollectionShowController, :logged_in_user, solr: true, type: :controller do
  describe "unpublished collection" do
    let(:collection) { create(:collection, published: false) }

    describe "non-logged-in user", logged_in_user: false do
      it "has permission denied" do
        get :index, params: { collection_id: collection.friendlier_id }
        expect(response).to redirect_to root_path
      end
    end

    describe "logged-in user", logged_in_user: true do
      it "can see page" do
        get :index, params: { collection_id: collection.friendlier_id }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "redirects searches with legacy params", solr: false do
    let(:collection_id) { "faked" }
    describe "sort" do
      let(:legacy_sort) { "system_create_dtsi desc" }
      let(:new_sort) { "recently_added" }

      let(:base_params) { { collection_id: collection_id, q: "some search", search_field: "all_fields" } }

      it "redirects" do
        get :index, params: base_params.merge(sort: legacy_sort)
        expect(response).to redirect_to(collection_path(base_params.merge(sort: new_sort)))
      end
    end
  end

  describe "Bad params" do
    let(:collection) { create(:collection, friendlier_id: "faked") }
    it "doesn't throw an error when facet.page is a hash" do
      get :facet, params: {
        id:              "subject_facet",
        collection_id:   collection.friendlier_id,
        "facet.page" =>  { goat: 'goat' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "doesn't throw an error when facet.page is an array" do
      get :facet, params: {
        id:              "subject_facet",
        collection_id:   collection.friendlier_id,
        "facet.page" =>  ['x', 'y']
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "sort", indexable_callbacks: true do
    render_views
    let(:requested_sort_order) { nil }
    let(:four_dates_in_desc_order) { (1..4).to_a.map { |i| i.days.ago } }
    let(:four_years_in_arbitrary_order) { [1992, 1990, 1991, 1993] }
    let(:four_titles_in_arbitrary_order) { ['4', '1', '3', '2'] }

    let!(:collection) { create(:collection, title: "The Collection", default_sort_field: default_sort_field) }
    let!(:works) {
      (0..3).to_a.map do |i|
        create(:work,
          title:          four_titles_in_arbitrary_order[i],
          published_at:   four_dates_in_desc_order[i],
          date_of_work:   [Work::DateOfWork.new(start: four_years_in_arbitrary_order[i])],
          contained_by:   [collection]
        )
      end
    }
    let(:base_params) { { collection_id: collection.friendlier_id, sort: requested_sort_order } }
    let(:parsed){ parsed = Nokogiri::HTML(response.body) }
    let(:titles_as_displayed) { parsed.css('.scihist-results-list-item-head a').map {|x| x.text} }
    let(:years_as_displayed) { parsed.css('span[itemprop="date_created"]').map {|x| x.text.strip } }
    let(:default_sort_field)  { nil }


    describe "no default sort order for this collection" do
      it "no default sort order for this collection: sort by date_published_dtsi desc" do
        get :index, params: base_params
        expect(titles_as_displayed).to eq four_titles_in_arbitrary_order
      end
    end

    describe "default sort order refers to a nonexistent sort field" do
      before do
        collection.update(default_sort_field:'goat')
        collection.save(validate:false)
      end
      it "sorts by the default sort" do
        get :index, params: base_params
        expect(titles_as_displayed).to eq four_titles_in_arbitrary_order
      end
    end

    describe "collection of serials with a default sort order: chron by publication date" do
      let(:default_sort_field) { 'oldest_date' }
      it "sorts in chron order using the publication date" do
        get :index, params: base_params
        expect(years_as_displayed).to eq ["1990", "1991", "1992", "1993"]
      end
    end

    describe "default order overridden from the front-end sort order menu" do
      let(:default_sort_field) { 'oldest_date' }
      let(:requested_sort_order) { 'newest_date'}
      it "uses the order requested by the user" do
        get :index, params: base_params
        expect(years_as_displayed).to eq ["1993", "1992", "1991", "1990"]
      end
    end

    describe "box and folder order" do

      let(:random_order) { (0..containers.length - 1).to_a.shuffle }

      let(:containers) do  
        [
          { "box"=> "1",  "folder"=> "1"  },
          { "box"=> "1" },
          
          { "box"=> "2",   "folder"=> "1"  },
          { "box"=> "2",   "folder"=> "2"  },

          { "box"=> "3",   "folder"=> "1"  },
          { "box"=> "3",   "folder"=> "2"  },
          { "box"=> "3-5", "folder"=> "6-4"},
          
          # Non-integer containers go at the end.
          {                "folder"=> "1"   },
          { "box"=> "??",  "folder"=> "goat"},
          {  }
        ]
      end


      let(:titles) do
        containers.map do |pc|
          "#{pc.try('box', 'none')},#{pc.try('folder', 'none')}"
        end   
      end

      let!(:works) do
        random_order.map do |i|
          create( :work,
            title:              titles[i],
            physical_container: Work::PhysicalContainer.new(containers[i]),
            contained_by:       [collection]
          )
        end
      end

      it "can sort by box and folder" do
        get :index, params: {"q"=>"", "sort"=>"box_folder", "collection_id"=> collection.friendlier_id }
        expect(titles_as_displayed).to eq titles
      end
    end

    describe "identical dates" do
      let(:default_sort_field) { 'oldest_date' }
      let(:four_years_in_arbitrary_order) { [1990, 1991, 1991, 1991] }
      it "uses title as tiebreaker sort field" do
        get :index, params: base_params
        expect(years_as_displayed).to eq  ["1990", "1991", "1991", "1991"]
        expect(titles_as_displayed).to eq ["4", "1", "2", "3"]
      end
    end
  end

  describe "#facet", indexable_callbacks: true do
    render_views

    let!(:collection) { create(:collection, friendlier_id: "faked", published: true) }
    let!(:collection_work) { create(:public_work, subject: ["Inside Subject 1", "Inside Subject 2"], contained_by: [collection]) }
    let!(:non_collection_work) { create(:public_work, subject: ["Outside Subject 1", "Outside Subject 2"]) }

    it "includes only collection work values" do
      get :facet, params: {
        id:              "subject_facet",
        collection_id:   collection.friendlier_id
      }

      doc = Nokogiri::HTML(response.body)

      collection_work.subject.each do |subject|
        expect(doc).to have_selector(".facet-values li", text: subject)
      end

      non_collection_work.subject.each do |subject|
        expect(doc).not_to have_selector(".facet-values li", text: subject)
      end
    end
  end
end
