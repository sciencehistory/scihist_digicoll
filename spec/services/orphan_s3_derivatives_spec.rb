require 'rails_helper'

describe OrphanS3Derivatives do

  let(:id_1) { "0001d800-482d-4dcf-80b7-84f273580a13" }
  let(:id_2) { "00042a06-7216-4ece-a57c-670e4e9b5c46" }

  let!(:work) do
    create(:public_work,
      members: [
        create(:asset_with_faked_file, id: id_1,
          faked_derivatives: {
             "download_full"   => create(:stored_uploaded_file, id: "#{id_1}/download_full/download_full.jpg"),
             "download_large"  => create(:stored_uploaded_file, id: "#{id_1}/download_large/download_large.jpg"),
             "download_medium" => create(:stored_uploaded_file, id: "#{id_1}/download_medium/download_medium.jpg"),
             "download_small"  => create(:stored_uploaded_file, id: "#{id_1}/download_small/download_small.jpg")
           }
        ),
        create(:asset_with_faked_file, id: id_2,
          faked_derivatives: {
             "download_full"   => create(:stored_uploaded_file, id: "#{id_2}/download_full/download_full.jpg"),
             "download_large"  => create(:stored_uploaded_file, id: "#{id_2}/download_large/download_large.jpg"),
             "download_medium" => create(:stored_uploaded_file, id: "#{id_2}/download_medium/download_medium.jpg"),
             "download_small"  => create(:stored_uploaded_file, id: "#{id_2}/download_small/download_small.jpg"),
          }
        )
      ]
    )
  end

  let(:work_with_oral_history_content) { create(:oral_history_work) }
  let(:m4a_path) { Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a" }

  let(:image_deriv_file_paths) do
    [
      "#{id_1}/download_full/download_full.jpg",
      "#{id_1}/download_large/download_large.jpg",
      "#{id_1}/download_medium/download_medium.jpg",
      "#{id_1}/download_small/download_small.jpg",
      "#{id_2}/download_full/download_full.jpg",
      "#{id_2}/download_large/download_large.jpg",
      "#{id_2}/download_medium/download_medium.jpg",
      "#{id_2}/download_small/download_small.jpg",
    ]
  end

  let(:missing_asset_image_deriv_file_paths) do
    [
      "missing_asset_id/download_full/download_full.jpg",
      "missing_asset_id/download_large/download_large.jpg",
    ]
  end

  let(:stale_asset_image_deriv_file_paths) do
    [
      "#{id_1}/download_full/stale_download_full.jpg",
      "#{id_1}/download_large/stale_download_full.jpg",
      "#{id_2}/download_full/stale_download_full.jpg",
      "#{id_2}/download_large/stale_download_full.jpg",
    ]
  end


  let(:combined_audio_file_paths) do
    [
      "combined_audio_derivatives/#{work_with_oral_history_content.id}/#{work_with_oral_history_content.oral_history_content!.combined_audio_m4a.id.split("/").last}"
    ]
  end

  let(:missing_oh_work_file_paths) do
    [
      "combined_audio_derivatives/missing_work_id/stale_combined_derivative.m4a"
    ]
  end

  let(:stale_combined_audio_file_paths) do
    [
      "combined_audio_derivatives/#{work_with_oral_history_content.id}/combined_stale.m4a"
    ]
  end

  let(:non_derivatives) do
    [
      "some_random/file.txt",
      "some_other_random/file.txt",
    ]
  end

  let (:orphan_checker) do
    OrphanS3Derivatives.new(show_progress_bar: false)
  end

  before do
    work_with_oral_history_content.oral_history_content.set_combined_audio_m4a!( File.open(m4a_path ))
    allow_any_instance_of(S3PathIterator).to receive(:s3_client).
      and_return(AwsHelpers::MockS3Client.new(paths: file_paths).client)
    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('arbitrary string')
    # Mute output. We just want to check the stats.
    allow_any_instance_of(S3PathIterator).to receive(:log).and_return(nil)
    allow_any_instance_of(OrphanS3Derivatives).to receive(:output_to_stderr).and_return(nil)
  end

  describe "good image derivatives" do
    let(:file_paths) do
      image_deriv_file_paths
    end
    it "checks all derivatives" do
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

  describe "combined audio: good derivatives" do
    let(:file_paths) do
      combined_audio_file_paths
    end
    it "checks the derivs" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 1
      expect(orphan_checker.orphans_found).to eq 0
    end
    it "deletes stale derivatives" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 0
    end
  end

  describe "combined audio: missing oral history work" do
    let(:file_paths) do
      missing_oh_work_file_paths
    end
    it "checks the derivs" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 1
      expect(orphan_checker.orphans_found).to eq 1
    end
    it "deletes stale derivatives" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 1
    end
  end

  describe "combined audio: stale combined audio derivatives" do
    let(:file_paths) do
      stale_combined_audio_file_paths
    end
    it "checks the derivs" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 1
      expect(orphan_checker.orphans_found).to eq 1
    end
    it "deletes stale derivatives" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 1
    end
  end

  describe "random non-derivatives" do
    let(:file_paths) do
      non_derivatives
    end
    it "identifies them" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 2
      expect(orphan_checker.orphans_found).to eq 2
    end
    it "deletes them" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 2
    end
  end
end