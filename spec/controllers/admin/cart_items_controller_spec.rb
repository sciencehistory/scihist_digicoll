require 'rails_helper'
RSpec.describe Admin::CartItemsController, :logged_in_user, type: :controller, queue_adapter: :test do


  let(:work_1) { FactoryBot.create(:work, :with_assets)}
  let(:work_2) { FactoryBot.create(:work, :with_assets)}
  let(:work_3) { FactoryBot.create(:work, :with_assets)}

  let(:work_4) { FactoryBot.create(:work)}
  let(:work_5) { FactoryBot.create(:work)}
  let(:work_6) { FactoryBot.create(:work)}

  let(:works_in_cart) {controller.current_user.works_in_cart.to_a}

  before do
    controller.current_user.works_in_cart = [work_1, work_2, work_3]
  end

  # See also the test for the cart_exporter itself at 
  # at spec/services/cart_exporter_spec.rb
  context "smoke test for report" do
    it "export smoke test" do
      post :report
      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).
        to eq 'text/csv'
      expect(response.headers["Content-Disposition"]).
        to match %r{attachment; filename=\"cart-report-.*.csv\"}
    end 
  end
  context "add /remove works from cart" do
    it "adds" do
      ids = [work_3, work_4, work_4, work_5, work_6].map{ |w| w.friendlier_id } + ['foo']
      post :update_multiple, params: { list_of_ids: ids, toggle: 1}, format: :json
      expect(works_in_cart).to match_array([work_1, work_2, work_3, work_4, work_5, work_6])
    end

    it "removes" do      
      ids = [work_1, work_1, work_3].map{ |w| w.friendlier_id } + ['foo']
      post :update_multiple, params: { list_of_ids: ids, toggle: 0 }, format: :json
      expect(works_in_cart).to match_array(work_2)
    end
  end

  context "export GAC" do
    let!(:work_1) do
      create(
        :public_work,
        members: [
          create(:asset_with_faked_file, faked_content_type: "image/tiff")
        ]
      )
    end

    let!(:work_2) do
      create(
        :public_work,
        members: [
          create(:asset_with_faked_file, faked_content_type: "image/tiff")
        ]
      )
    end

    let(:scope) { Work.where(id: [work_1.id, work_2.id]) }

    it "builds a zip file that includes a manifest.csv and asset entries" do
      get :google_arts_and_culture_export
      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/zip') # Or your specific content type
      expect(response.headers['Content-Disposition']).to include "attachment; filename=\"google-arts-and-culture-export-#{Date.today.to_s}.zip\""
      entry_names = []
      zip_io = StringIO.new(response.body)
      Zip::InputStream.open(zip_io) do |io|
        while entry = io.get_next_entry
          entry_names << entry.name
        end
      end
      expect(entry_names[0]).to eq "metadata.csv"
      expect(entry_names[1]).to match "test_title_.*\.jpg"
      expect(entry_names[2]).to match "test_title_.*\.jpg"
    ensure
      zip_io.close if zip_io
    end
  end
end
