require 'rails_helper'

# Note: we have two Works controllers,
# works_controller.rb
# admin/works_controller.rb
# This one tests only the first.


RSpec.describe WorksController, type: :controller do
  context "smoke tests" do
    context "standard work" do
      render_views

      let(:work){ create(:public_work, :published, members: [create(:asset_with_faked_file), create(:asset_with_faked_file)]) }

      it "shows the work as expected" do
        get :show, params: { id: work.friendlier_id }, as: :html
        expect(response.status).to eq(200)

        # We don't intend to ever actually load work.members, instead doing
        # special purpose stuff in the ViewComponent. It's too easy to load too
        # much. let's test to make sure we don't.
        expect(assigns[:work].members.loaded?).to be(false)
      end

      it 'allows user to download RIS citation' do
        get :show, params: { id: work.friendlier_id }, as: :ris
        expect(response.status).to eq(200)
        expect(response.body).to include "TI  - Test title"
        expect(response.body).to include "M2  - Courtesy of Science History Institute."
        expect(response.media_type).to eq "application/x-research-info-systems"
        expect(response.headers["Content-Disposition"]).
          to match %r{attachment; filename=\"test_title_#{ work.friendlier_id }.ris\"(; filename*=UTF-8''test_title_2iwaufv.ris)?}
      end

      it "delivers oai_dc from XML request" do
        get :show, params: { id: work.friendlier_id }, as: :xml
        expect(response.status).to eq(200)
        expect(response.media_type).to eq "application/xml"

        parsed = Nokogiri::XML(response.body)
        expect(parsed.root&.namespace&.href).to eq "http://www.openarchives.org/OAI/2.0/oai_dc/"
        expect(parsed.root&.name).to eq "dc"
      end
    end
  end

  context("#viewer_images_info") do
    let(:unpublished_asset) { create(:asset_with_faked_file, published: false )}
    let(:work) { create(:public_work, members: [create(:asset_with_faked_file), unpublished_asset]) }

    it "returns JSON" do
      get :viewer_images_info, params: { id: work.friendlier_id }, as: :json
      expect(response.status).to eq(200)
      expect(response.media_type).to eq "application/json"

      parsed = JSON.parse(response.body)

      expect(parsed).to be_kind_of(Array)
      expect(parsed.length).to eq 1
    end

    describe "with logged-in user", :logged_in_user do
      it "includes unpublished items" do
        get :viewer_images_info, params: { id: work.friendlier_id }, as: :json

        parsed = JSON.parse(response.body)

        expect(parsed).to be_kind_of(Array)
        expect(parsed.length).to eq 2
      end
    end
  end

  context("#viewer_search") do
    let(:unpublished_asset) { create(:asset_with_faked_file, :with_ocr, published: false )}
    let(:work) { create(:public_work, members: [create(:asset_with_faked_file, :with_ocr), unpublished_asset]) }

    context "without query" do
      it "returns error" do
        get :viewer_search, params: { id: work.friendlier_id }
        expect(response).to have_http_status(422)
      end

      it "returns error from normalized empty query too" do
        get :viewer_search, params: { id: work.friendlier_id, q: " ;  ; " }
        expect(response).to have_http_status(422)
      end
    end



    it "returns JSON, not including unpublished item" do
      get :viewer_search, params: { id: work.friendlier_id, q: "unit" }, as: :json
      expect(response.status).to eq(200)
      expect(response.media_type).to eq "application/json"

      parsed = JSON.parse(response.body)

      expect(parsed).to be_kind_of(Array)
      expect(parsed.length).to eq 1
    end

    describe "with logged-in user", :logged_in_user do
      it "includes unpublished items" do
        get :viewer_search, params: { id: work.friendlier_id, q: "unit" }, as: :json

        parsed = JSON.parse(response.body)

        expect(parsed).to be_kind_of(Array)
        expect(parsed.length).to eq 2
      end
    end
  end

  ["transcription", "english_translation"].each do |trans_text_type|
    context trans_text_type do
      context "no suitable text" do
        let(:work) { create(:public_work) }
        it "404s" do
          expect {
            get trans_text_type, params: { id: work.friendlier_id }, as: :pdf
          }.to raise_error(ActionController::RoutingError)
        end
      end

      context "suitable text" do
        render_views

        let(:unpublished_asset) { create(:asset_with_faked_file, published: false, trans_text_type => "do not include me", position: 10) }

        let(:work) { create(:public_work, title: "this is my work",
          members: [
            create(:asset_with_faked_file, trans_text_type => "text 2\n\nparagraph 2-2", position: 2),
            create(:asset_with_faked_file, trans_text_type => "text 1\n\nparagraph 1-2", position: 1),
            unpublished_asset
          ])
        }

        let(:published_ordered_members) {
          work.members.select(&:published).sort_by(&:position)
        }

        it "has good filename" do
          get trans_text_type, params: { id: work.friendlier_id }, as: :pdf

          expect(response.headers["Content-Disposition"]).to include("this_is_my_#{work.friendlier_id}_#{trans_text_type}.pdf")
        end

        context "unpublished work" do
          let(:work) { create(:work, title: "this is my work", published: false,
            members: [
              create(:asset_with_faked_file, trans_text_type => "text 1\n\nparagraph 1-2", position: 1),
            ])
          }

          it "denies access" do
            get trans_text_type, params: { id: work.friendlier_id }, as: :pdf

            expect(response).to redirect_to root_path
            expect(flash.alert).to match /You don't have permission to access/
          end
        end
      end
    end
  end

  context "JSON work represnetation" do
    let(:work){ create(:public_work, :published) }

    it "smoke test" do
      get :show, params: { id: work.friendlier_id }, as: :json
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to be_kind_of(Hash)
    end
  end
  context "#lazy_member_images" do
    let(:work){ create(:public_work, :published) }

    it "smoke test" do
      get :lazy_member_images, params: { id: work.friendlier_id}
      expect(work.members.count).to eq 1
      expect(response.status).to eq(200)
    end

    it "can handle weird start_index and images_per_page values" do
      get :lazy_member_images, params: { id: work.friendlier_id, start_index: -9035.4, images_per_page: "asdasd"}
      expect(response.status).to eq(200)
    end

    context "work with five images" do
      let(:asset1) {
        create(:asset_with_faked_file, faked_derivatives: {}, position: 0)
      }
      let(:asset2) {
        create(:asset_with_faked_file, faked_derivatives: {},  position: 1)
      }
      let(:asset3) {
        create(:asset_with_faked_file, faked_derivatives: {},  position: 2)
      }
      let(:asset4) {
        create(:asset_with_faked_file, faked_derivatives: {},  position: 3)
      }
      let(:asset5) {
        create(:asset_with_faked_file, faked_derivatives: {},  position: 4)
      }
      let(:members) {[asset1, asset2, asset3, asset4, asset5]}
      let(:work) {
        create(:work, :published, members: members, representative: asset1)
      }
      it "shows items 3-5 correctly" do
        get :lazy_member_images, params: { id: work.friendlier_id, start_index: 2, images_per_page: 3}
        expect(response.status).to eq(200)
      end
    end
  end
end
