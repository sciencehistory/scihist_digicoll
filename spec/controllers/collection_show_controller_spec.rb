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
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "doesn't throw an error when facet.page is an array" do
      get :facet, params: {
        id:              "subject_facet",
        collection_id:   collection.friendlier_id,
        "facet.page" =>  ['x', 'y']
      }
      expect(response).to have_http_status(:unprocessable_content)
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

      describe "works with non-numeric boxes and folders" do
        let!(:works) do
          [
            create( :work,
              title:              "1",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "1"   }),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "a",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "a"   }),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "b",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "b"   }),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "empty physical_container",
              physical_container: (Work::PhysicalContainer.new({})),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "nil physical_container a",
              physical_container: nil,
              contained_by:       [collection]
            ),
            create( :work,
              title:              "nil physical_container b",
              physical_container: (Work::PhysicalContainer.new({})),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "nil physical_container c",
              physical_container: nil,
              contained_by:       [collection]
            ),
          ].shuffle
        end
        it "go at the end, sorted by title" do
          get :index, params: {"q"=>"", "sort"=>"box_folder", "collection_id"=> collection.friendlier_id }
          expect(titles_as_displayed).to eq ["1", "a", "b",
            "empty physical_container",
            "nil physical_container a", "nil physical_container b", "nil physical_container c"]
        end
      end


      describe "works within same non-integer box" do
        let!(:works) do
          [
            create( :work,
              title:              "za",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "z", "box" => "a" }),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "aa",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "a", "box" => "a" }),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "ab",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "a", "box" => "b" }),
              contained_by:       [collection]
            ),
            create( :work,
              title:              "ac",
              physical_container: Work::PhysicalContainer.new({ "folder"=> "a", "box" => "c" }),
              contained_by:       [collection]
            ),
          ].shuffle
        end
        it "go at the end, sorted by title" do
          get :index, params: {"q"=>"", "sort"=>"box_folder", "collection_id"=> collection.friendlier_id }
          expect(titles_as_displayed).to eq  ["aa", "ab", "ac", "za"]
        end

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

  describe "display box and folder", indexable_callbacks: true do
    render_views
    let!(:collection) { create(:collection, title: "The Collection") }
    let(:parsed){ parsed = Nokogiri::HTML(response.body) }
    let(:containers_as_displayed) { parsed.css('.scihist-results-list-item-box-and-folder').map {|x| x.text} }
    let(:titles_as_displayed) { parsed.css('.scihist-results-list-item-head a').map {|x| x.text} }

    describe "empty box / folder" do
      let!(:works) do
        [
          create( :work,
            department:         "Archives",
            title:              "Work with box and folder",
            physical_container: Work::PhysicalContainer.new({ "box" => "1", "folder"=> "1" }),
            contained_by:       [collection]
          ),
          create( :work,
            department:         "Archives",
            title:              "Work with just a folder",
            physical_container: Work::PhysicalContainer.new({ "folder"=> "goat" }),
            contained_by:       [collection]
          ),
          create( :work,
            department:         "Archives",
            title:              "Empty physical_container",
            physical_container: (Work::PhysicalContainer.new({})),
            contained_by:       [collection]
          ),
          create( :work,
            department:         "Archives",
            title:              "Nil physical_container",
            physical_container: nil,
            contained_by:       [collection]
          ),
        ].shuffle
      end

      it "displays fine" do
        get :index, params: {"q"=>"", "sort"=>"box_folder", "collection_id"=> collection.friendlier_id }
        expect(titles_as_displayed).to match_array [ "Work with box and folder",
          "Work with just a folder",
          "Empty physical_container",
          "Nil physical_container"
        ]

        expect(containers_as_displayed).to eq [
          "Box 1, Folder 1",
          "Folder goat"
        ]
      end
    end
    describe "works in different departments" do
      let!(:works) do
        [
          create( :work,
            department: "Archives",
            title: "1",
            physical_container: Work::PhysicalContainer.new({ "box" => "1", "folder"=> "1" }),
            contained_by: [collection]
          ),
          create( :work,
            department: "Museum",
            title: "2",
            physical_container: Work::PhysicalContainer.new({ "box" => "2", "folder"=> "2" }),
            contained_by: [collection]
          )
        ].shuffle
      end
      it "only shows box / folder info for the archives works" do
        get :index, params: {"q"=>"", "sort"=>"box_folder", "collection_id"=> collection.friendlier_id }
        expect(containers_as_displayed).to match_array  ["Box 1, Folder 1"]
      end
    end
  end

  describe "search form with box and folder", indexable_callbacks: true do
    render_views
    describe "smoke test" do
      let(:b1f1) {
        Work::PhysicalContainer.new({ box:1, folder:1 })
      }
      let(:b1f2) {
        Work::PhysicalContainer.new({ box:1, folder:2 })
      }
      let(:b12f1) {
        Work::PhysicalContainer.new({ box:12, folder:1 })
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
      it "finds works by box and folder" do
        get :index, params: box_and_folder_params
        expect(response).to have_http_status(200)
        expect(response.body).to     include(works[0].title)
        expect(response.body).to     include(works[1].title)
        expect(response.body).not_to include(works[2].title)
        # Box numbers treated like integers, not strings:
        # A search for box "1" should not match box "12"
        expect(response.body).not_to include(works[3].title)
      end
      it "requires user to specify containing box" do
        get :index, params: {"q"=>"", "folder_id"=>"1", "sort"=>"", "collection_id"=> collection.friendlier_id }
        expect(response).to have_http_status(200)
        expect(response.body).to include("If you specify a folder, please also specify a box")
      end
    end
   describe "edge cases" do
      let(:parsed){ parsed = Nokogiri::HTML(response.body) }
      let(:titles_as_displayed) { parsed.css('.scihist-results-list-item-head a').map {|x| x.text} }
      let!(:work) { create(:work, :published,
        title: "archival_work",
        physical_container: Work::PhysicalContainer.new({
          "box"=>"apples, pears and mangos 1234",
          "folder"=> "lions and tigers and bears oh my 5678"
        }),
        contained_by:   [collection])
      }
      let!(:collection) { create(:collection, friendlier_id: "faked", department: "Archives") }
      it "does not return works that don't match" do
        get :index, params: {
          "q"=>"",
          "box_id"=>"goat",
          "folder_id"=>"goat",
          "sort"=>"",
          "collection_id"=> collection.friendlier_id
        }
        expect(response.body).not_to include(work.title)
      end
      it "matches partial matches" do
        get :index, params: {
          "q"=>"",
          "box_id"=>"pears",
          "folder_id"=>"bears",
          "sort"=>"",
          "collection_id"=> collection.friendlier_id
        }
        expect(response.body).to include(work.title)
      end
      it "matches partial matches in any order" do
        get :index, params: {
          "q"=>"",
          "box_id"=>"mangos, pears",
          "folder_id"=>"bears,lions",
          "sort"=>"",
          "collection_id"=> collection.friendlier_id
        }
        expect(response.body).to include(work.title)
      end
      it "returns exact matches" do
        get :index, params: {
          "q"=>"",
          "box_id"=> work.physical_container.box,
          "folder_id"=> work.physical_container.folder,
          "sort"=>"",
          "collection_id"=> collection.friendlier_id
        }
        expect(response.body).to include(work.title)
      end
      it "123 should not match 1234" do
        get :index, params: {
          "q"=>"",
          "box_id"=>"12",
          "sort"=>"",
          "collection_id"=> collection.friendlier_id
        }
        expect(response.body).not_to include(work.title)
      end
      it "is case insensitive" do
        get :index, params: {
          "q"=>"",
          "box_id"=>"PeArS",
          "folder_id"=>"BeArS",
          "sort"=>"",
          "collection_id"=> collection.friendlier_id
        }
        expect(response.body).to include(work.title)
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
