require 'rails_helper'

describe OrphanS3RestrictedDerivatives do

  let(:fake_aws_s3_client) { Aws::S3::Client.new(stub_responses: true) }

  let(:id_1) { "0001d800-482d-4dcf-80b7-84f273580a13" }
  let(:id_2) { "00042a06-7216-4ece-a57c-670e4e9b5c46" }

  let!(:work) do
    create(:public_work,
      members: [
        create(:asset_with_faked_file,
          id: id_1,
          derivative_storage_type: "restricted",
          faked_derivatives: {
             "download_full"   => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_1}/download_full/download_full.jpg"),
             "download_large"  => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_1}/download_large/download_large.jpg"),
             "download_medium" => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_1}/download_medium/download_medium.jpg"),
             "download_small"  => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_1}/download_small/download_small.jpg")
           }
        ),
        create(:asset_with_faked_file,
          id: id_2,
          derivative_storage_type: "restricted",
          faked_derivatives: {
             "download_full"   => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_2}/download_full/download_full.jpg"),
             "download_large"  => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_2}/download_large/download_large.jpg"),
             "download_medium" => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_2}/download_medium/download_medium.jpg"),
             "download_small"  => create(:stored_uploaded_file, storage: :restricted_kithe_derivatives, id: "#{id_2}/download_small/download_small.jpg"),
          }
        )
      ]
    )
  end

  let(:image_deriv_file_paths) do
    [
      "restricted_derivatives/#{id_1}/download_full/download_full.jpg",
      "restricted_derivatives/#{id_1}/download_large/download_large.jpg",
      "restricted_derivatives/#{id_1}/download_medium/download_medium.jpg",
      "restricted_derivatives/#{id_1}/download_small/download_small.jpg",
      "restricted_derivatives/#{id_2}/download_full/download_full.jpg",
      "restricted_derivatives/#{id_2}/download_large/download_large.jpg",
      "restricted_derivatives/#{id_2}/download_medium/download_medium.jpg",
      "restricted_derivatives/#{id_2}/download_small/download_small.jpg",
    ]
  end

  let(:missing_asset_image_deriv_file_paths) do
    [
      "restricted_derivatives/missing_asset_id/download_full/download_full.jpg",
      "restricted_derivatives/missing_asset_id/download_large/download_large.jpg",
    ]
  end

  let(:stale_asset_image_deriv_file_paths) do
    [
      "restricted_derivatives/#{id_1}/download_full/stale_download_full.jpg",
      "restricted_derivatives/#{id_1}/download_large/stale_download_full.jpg",
      "restricted_derivatives/#{id_2}/download_full/stale_download_full.jpg",
      "restricted_derivatives/#{id_2}/download_large/stale_download_full.jpg",
    ]
  end


  let(:fake_aws_list_output) do
     Aws::S3::Types::ListObjectsOutput.new(
      is_truncated: false,   marker: '',
      next_marker: nil,      name: 's3.bucket',
      delimiter: '/',        max_keys: 1000,
      encoding_type: 'url',
      contents: file_paths.map{|path| Struct.new(:key).new(path)},
      common_prefixes: []
    )
  end

  let (:orphan_checker) do
    OrphanS3RestrictedDerivatives.new(show_progress_bar: false)
  end

  before do
    fake_aws_s3_client.stub_responses(:list_objects_v2, fake_aws_list_output)
    allow_any_instance_of(S3PathIterator).to receive(:s3_client).and_return(fake_aws_s3_client)
    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('s3.bucket')
    # Mute output. We just want to check the stats.
    allow_any_instance_of(S3PathIterator).to receive(:log).and_return(nil)
    allow_any_instance_of(OrphanS3RestrictedDerivatives).to receive(:output_to_stderr).and_return(nil)
  end

  describe "good image derivatives" do
    let(:file_paths) do
      image_deriv_file_paths
    end
    it "checks all derivatives" do
      asset_1, asset_2 =  work.members

      asset_1.file_derivatives.values.each do |deriv|
        expect(deriv.storage_key).to eq(:restricted_kithe_derivatives)
      end

      asset_2.file_derivatives.values.each do |deriv|
        expect(deriv.storage_key).to eq(:restricted_kithe_derivatives)
      end

     orphan_checker.report_orphans
     expect(orphan_checker.files_checked).to eq 8
     expect(orphan_checker.orphans_found).to eq 0
    end
    it "doesn't delete anything" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 0
    end
  end

  describe "image derivatives: asset missing" do
    let(:file_paths) do
      missing_asset_image_deriv_file_paths
    end
    it "detects problems" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 2
      expect(orphan_checker.orphans_found).to eq 2
    end
    it "deletes stale derivatives" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 2
    end
  end

  describe "image derivatives: stale derivatives" do
    let(:file_paths) do
      stale_asset_image_deriv_file_paths
    end
    it "detects problems" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 4
      expect(orphan_checker.orphans_found).to eq 4
    end
    it "deletes stale derivatives" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 4
    end
  end
end