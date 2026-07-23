require 'rails_helper'

RSpec.describe Admin::CollectionsController, :logged_in_user, type: :controller do
  describe "admin user", logged_in_user: :admin do
    it "can create a published collection" do
      post :create, params: { collection: { title: "newly created collection", published: "1", department: "Archives" } }
      newly_created = Collection.find_by_title("newly created collection")
      expect(newly_created).to be_present
      expect(newly_created.published?).to be true
    end

    describe "#generate_qr_code" do
      let(:collection) { create(:collection) }

      it "returns an inline PNG named after the collection" do
        get :generate_qr_code, params: { id: collection.friendlier_id }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq "image/png"
        expect(response.headers["Content-Disposition"]).to include("inline")
        expect(response.headers["Content-Disposition"]).to include("qr_col_#{collection.friendlier_id}.png")
        # a valid PNG signature
        expect(response.body[0, 8].bytes).to eq [137, 80, 78, 71, 13, 10, 26, 10]
      end

      it "includes box and folder in the url and filename when given" do
        received_url = nil
        allow(QrCodeCreator).to receive(:new) do |url, **_opts|
          received_url = url
          instance_double(QrCodeCreator, call: ChunkyPNG::Image.new(1, 1))
        end

        get :generate_qr_code, params: { id: collection.friendlier_id, box: "5", folder: "2" }

        expect(received_url).to include("/collections/#{collection.friendlier_id}")
        expect(received_url).to include("box_id=5")
        expect(received_url).to include("folder_id=2")
        expect(response.headers["Content-Disposition"]).to include("qr_col_#{collection.friendlier_id}_b5f2.png")
      end
    end

    context "filter collections" do
      render_views
      let!(:collection) {
        create(:collection, title: "Newly created collection", external_id: [
          Work::ExternalId.new( {"value"=>"2010.028", "category"=>"accn"} ),
        ])
      }
      it "can filter on external id, regardless of the category of the ID" do
        get :index, params: { title_or_id: "2010.028" }
        rows = response.parsed_body.css('.table.admin-list tbody tr')
        expect(rows.length).to eq 1
      end
      it "can filter on partial title" do
        get :index, params: { title_or_id: "newly" }
        rows = response.parsed_body.css('.table.admin-list tbody tr')
        expect(rows.length).to eq 1
      end
    end
  end

  context "sql escaping" do
    render_views
    let(:quotey_string) { " \\\''''  Bellen's \"lecture\" \\\'''' " }
    let(:rows) { response.parsed_body.css '.table.admin-list tbody tr' }

    context "sql escaping for title" do
      let!(:collection) { create(:collection, title: quotey_string) }
      it "matches title" do
        get :index, params:{"title_or_id"=> quotey_string }
        expect(rows.length).to eq 1
      end
    end
    context "sql escaping" do
      let!(:collection) { create(:collection, external_id: [
        Work::ExternalId.new( {"value"=>quotey_string,   "category"=>"accn"} ),
      ]) }
      it "matches external_id" do
        get :index, params:{"title_or_id"=> quotey_string }
        expect(rows.length).to eq 1
      end
    end
  end
end
