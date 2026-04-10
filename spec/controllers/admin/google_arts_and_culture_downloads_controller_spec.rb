require 'rails_helper'
RSpec.describe Admin::GoogleArtsAndCultureDownloadsController, :logged_in_user, type: :controller, queue_adapter: :test do

  let!(:eligible_museum_work) do
    create(
      :public_work,
      title: "Museum",
      department: "Museum",
      format: ['physical_object'],
      rights: 'https://creativecommons.org/licenses/by/4.0/',
      created_at: Time.parse("2020-01-01"),
      updated_at: Time.parse("2021-01-01"),
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let!(:eligible_library_work) do
    create(
      :public_work,
      title: "Library",
      department: 'Library',
      format: ['image'],
      rights: 'http://creativecommons.org/publicdomain/mark/1.0/',
      created_at: Time.parse("2022-01-01"),
      updated_at: Time.parse("2023-01-01"),
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  let!(:archives_work) do
    create(
      :public_work,
      title: "Archives",
      department: 'Archives',
      created_at: Time.parse("2022-01-01"),
      updated_at: Time.parse("2023-01-01"),
      members: [
        create(:asset_with_faked_file, faked_content_type: "image/tiff")
      ]
    )
  end

  context "#load_into_cart", :admin_user do
    it "loads the archives and museum work into cart" do
      expect(controller.current_user.works_in_cart.count).to eq 0
      get :load_into_cart
      expect(controller.current_user.works_in_cart.count).to eq 2
      titles = controller.current_user.works_in_cart.map {|w| w.title}.sort
      expect(titles).to eq(["Museum", "Library"])
    end

    it "loads the archives and museum work into cart" do
      expect(controller.current_user.works_in_cart.count).to eq 0
      get :load_into_cart, params: {
        "load_into_cart" => {
          "created_at_start_date" =>  "2026-04-02",
          "created_at_end_date" =>    "2026-04-08",
          "modified_at_start_date" => "2026-04-08",
          "modified_at_end_date" =>   "2026-04-18"
        }
      }
      expect(controller.current_user.works_in_cart.count).to eq 0
    end



	end



  context "export GAC" do

    let(:scope) { Work.where(id: [work_1.id, work_2.id]) }



  #   it "builds a zip file that includes a manifest.csv and asset entries" do
  #     get :export_cart
  #     expect(response).to have_http_status(:found)
  #     expect(response.headers['Content-Type']).to eq('application/zip') # Or your specific content type
  #     expect(response.headers['Content-Disposition']).to include "attachment; filename=\"google-arts-and-culture-export-#{Date.today.to_s}.zip\""
  #     entry_names = []
  #     zip_io = StringIO.new(response.body)
  #     Zip::InputStream.open(zip_io) do |io|
  #       while entry = io.get_next_entry
  #         entry_names << entry.name
  #       end
  #     end
  #     expect(entry_names[0]).to eq "metadata.csv"
  #     expect(entry_names[1]).to match "test_title_.*\.jpg"
  #     expect(entry_names[2]).to match "test_title_.*\.jpg"
  #   ensure
  #     zip_io.close if zip_io
  #   end
  end
end