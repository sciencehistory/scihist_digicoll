require 'rails_helper'

describe "AssetDerivativeStorageTypeAuditor" do
  let(:sample_file_location) {  Rails.root + "spec/test_support/images/20x20.png" }

  let!(:published_asset) do
    create(:asset_with_faked_file,
           published: true,
           faked_derivatives: {
             "thumb_small" => create(:stored_uploaded_file,
                file: File.open(sample_file_location),
                storage: "kithe_derivatives",
                content_type: "image/png"),
             "thumb_large" => create(:stored_uploaded_file,
                file: File.open(sample_file_location),
                storage: "kithe_derivatives",
                content_type: "image/png"),
           }
    )
  end

  let!(:restricted_derivative_asset) { create(:asset_with_faked_file, :restricted_derivatives) }

  let(:auditor) { AssetDerivativeStorageTypeAuditor.new }

  describe "with no failures" do
    it "does not failed_assets?" do
      expect(auditor.check_all).to be(true)
      expect(auditor.failed_assets?).to be(false)
    end

    describe "#perform!" do
      it "does not send notifications, but logs the fact that the check took place" do
        expect(Honeybadger).not_to receive(:notify)
        expect {
          auditor.perform!
        }.not_to change { ActionMailer::Base.deliveries.count }

        expect(Admin::AssetDerivativeStorageTypeReport.count).to eq 1
        report_data = Admin::AssetDerivativeStorageTypeReport.first.data_for_report
        expect(report_data['incorrectly_published_count']).to be_nil
        expect(report_data['incorrect_storage_locations_count']).to be_nil
        expect(report_data['start_time']).to be_present
        expect(report_data['end_time']).to be_present
      end
    end
  end

  describe "with failures" do
    let!(:published_with_restricted_derivatives) do
      create(:asset_with_faked_file, :restricted_derivatives).tap { |a| a.update(published: true) }
    end

    let!(:mismatched_storage_locations) do
      # update in DB without triggering rails callback, so we can force inconsistency
      a = create(:asset_with_faked_file, :restricted_derivatives)
      a.save!
      a.update_column("json_attributes", a.json_attributes.merge("derivative_storage_type" => "public"))
      a
    end

    it "fails audit" do
      expect(auditor.check_all).to be(false)
      expect(auditor.failed_assets?).to be(true)

      expect(auditor.incorrectly_published).to eq([published_with_restricted_derivatives])
      expect(auditor.incorrect_storage_locations).to eq([mismatched_storage_locations])
    end

    describe "#perform!" do
      it "sends notifications and logs report" do
        expect(Honeybadger).to receive(:notify).with("Assets with unexpected derivative_storage_type state found", any_args)

        expect {
          auditor.perform!
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(Admin::AssetDerivativeStorageTypeReport.count).to eq 1
        report_data = Admin::AssetDerivativeStorageTypeReport.first.data_for_report
        expect(report_data['incorrectly_published_count']).to eq 1
        expect(report_data['incorrect_storage_locations_count']).to eq 1
        expect(report_data[
          'incorrectly_published_sample'
        ]).to eq published_with_restricted_derivatives.friendlier_id
        expect(report_data[
          'incorrect_storage_locations_sample'
        ]).to eq mismatched_storage_locations.friendlier_id

        expect(report_data['start_time']).to be_present
        expect(report_data['end_time']).to be_present
      end
    end
  end

  describe "A series of reports are saved to the database" do
    let(:cls) { Admin::AssetDerivativeStorageTypeReport }
    let(:auditor) { AssetDerivativeStorageTypeAuditor.new }
    let!(:series_of_reports) do
      [
        cls.create!(created_at: 1.days.ago),
        cls.create!(created_at: 2.days.ago),
        cls.create!(created_at: 3.days.ago),
        cls.create!(created_at: 4.days.ago),
      ]
    end
    it "auditor keeps only the most recent" do
      expect(cls.count).to eq 4
      auditor.perform!
      expect(cls.count).to eq 1
      expect(cls.first.created_at).to be_within(5.seconds).of Time.now
    end
  end
end
