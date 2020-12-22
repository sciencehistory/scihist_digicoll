require 'rails_helper'
RSpec.describe Admin::StorageReportController, :logged_in_user, type: :controller do
  describe "admin storage report controller", logged_in_user: :admin do
    context "nothing in the report table" do
      it "smoke test: no errors even if nothing in the table" do
        expect(Admin::AssetDerivativeStorageTypeReport.count).to eq 0
        get :index
        expect(response.code).to eq "200"
      end
    end
    context "a report  in the table" do
      let!(:storage_report) do
        data = {
            start_time: Time.now.to_s,
            end_time:   Time.now.to_s,
            incorrectly_published_sample: "",
            incorrectly_published_count: 0,
            incorrect_storage_locations_sample: "",
            incorrect_storage_locations_count: 0,
        }
        Admin::AssetDerivativeStorageTypeReport.create( data_for_report: data)
      end
      it "smoke test: can show the report" do
        expect(Admin::AssetDerivativeStorageTypeReport.count).to eq 1
        get :index
        expect(response.code).to eq "200"
      end
    end

    context "a report  in the table with nil values" do
      let!(:storage_report) do
        data = {
            start_time: Time.now.to_s,
            end_time:   Time.now.to_s,
            incorrectly_published_sample: nil,
            incorrectly_published_count: nil,
            incorrect_storage_locations_sample: nil,
            incorrect_storage_locations_count: nil,
        }
        Admin::AssetDerivativeStorageTypeReport.create( data_for_report: data)
      end
      it "Shows the report without errors" do
        expect(Admin::AssetDerivativeStorageTypeReport.count).to eq 1
        get :index
        expect(response.code).to eq "200"
      end
    end

  end
end