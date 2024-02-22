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
        expect(response).to redirect_to(new_user_session_path)
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
    let(:four_titles_in_arbitrary_order) { ['4', '1', '3', '2'] }

    let!(:collection) { create(:collection, title: "The Collection", default_sort_field: default_sort_field) }
    let!(:works) {
      (0..3).to_a.map do |i|
        create(:work,
          title:          four_titles_in_arbitrary_order[i],
          published_at:   four_dates_in_desc_order[i],
          updated_at:     four_dates_in_desc_order[i],
          contained_by:   [collection]
        )
      end
    }
    let(:base_params) { { collection_id: collection.friendlier_id, sort: requested_sort_order } }
    let(:parsed){ parsed = Nokogiri::HTML(response.body) }
    let(:titles_in_order) { parsed.css('.scihist-results-list-item-head a').map {|x| x.text} }

    describe "no default sort order for this collection" do
      let(:default_sort_field)  { nil }
      it "no default sort order for this collection: sort by date_published_dtsi desc" do
        get :index, params: base_params
        expect(titles_in_order).to eq four_titles_in_arbitrary_order
      end
    end


    describe "collection of serials with a default sort order: reverse chron by date modified" do
      let(:default_sort_field) { 'date_modified_desc' }
      it "sorts in reverse updated_at order" do
        get :index, params: base_params
        expect(titles_in_order).to eq four_titles_in_arbitrary_order
      end
    end

    describe "default order overridden from the front-end sort order menu" do
      let(:default_sort_field) { 'date_modified_desc' }      
      let(:requested_sort_order) { 'date_modified_asc'}
      it "uses the order requested by the user" do
        get :index, params: base_params
        expect(titles_in_order).to eq  four_titles_in_arbitrary_order.reverse
      end
    end

    # "it would be ideal for the Distillations and Chemical Heritage collections chronologically sorted by default, from oldest to newest."
    describe "collection of serials with a default sort order of earliest_date desc, title asc" do
      let(:default_sort_field) { 'oldest_date' }
      let(:works) { [
        create(:work,
          date_of_work:   [Work::DateOfWork.new(start: '1990')],
          title:          "Distillations, Volume 3 Number 1",
          contained_by:   [collection]
        ),
        create(:work,
          date_of_work:   [Work::DateOfWork.new(start: '1991')],
          title:          "Distillations, Volume 3 Number 2",
          contained_by:   [collection]
        ),
        create(:work,
          date_of_work:   [Work::DateOfWork.new(start: '1991')],
          title:          "Distillations, Volume 3 Number 3",
          contained_by:   [collection]
        ),
        create(:work,
          date_of_work:   [Work::DateOfWork.new(start: '1991')],
          title:          "Distillations, Volume 3 Number 4",
          contained_by:   [collection]
        )
      ] }
      it "sorts by date, with the title acting as tiebreaker" do
        get :index, params: base_params
        expect(titles_in_order).to eq [
          "Distillations, Volume 3 Number 1",
          "Distillations, Volume 3 Number 2",
          "Distillations, Volume 3 Number 3",
          "Distillations, Volume 3 Number 4"
        ]
      end
    end
  end
end
