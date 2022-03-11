require 'rails_helper'

describe OrphanS3Originals do
  let(:asset_n)  {
    create(:asset, :inline_promoted_file,
      file: File.open((Rails.root + "spec/test_support/images/20x20.png"))
    )
  }
  let(:asset_v)  {
    create(:asset, :inline_promoted_file,
      file: File.open((Rails.root + "spec/test_support/video/sample_video.mp4"))
    )
  }
  let(:file_paths_v) {['va', 'vb', 'vc']}
  let(:file_paths_n) {['na', 'nb', 'nc']}

  let(:v_prefix) { ScihistDigicoll::Env.shrine_store_video_storage.prefix }
  let(:n_prefix) { ScihistDigicoll::Env.shrine_store_storage.      prefix }

  let(:fake_clients) do
    {
      video:    AwsHelpers::MockS3Client.new(paths: file_paths_v).client,
      nonvideo: AwsHelpers::MockS3Client.new(paths: file_paths_n).client
    }
  end



  let(:orphan_checker) do
    OrphanS3Originals.new(show_progress_bar: false)
  end

  before do
    allow_any_instance_of(S3PathIterator).to receive(:log).and_return(nil)
    allow(orphan_checker).to receive(:output_to_stderr).and_return(nil)
    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('not using s3')
    allow(orphan_checker.nonvideo_s3_iterator).
      to receive(:s3_client).and_return(fake_clients[:nonvideo])
    allow(orphan_checker.video_s3_iterator).
      to receive(:s3_client).and_return(fake_clients[:video])
  end

  describe "orphan checker smoke test" do
    it "smoke test" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 6
      expect(orphan_checker.orphans_found).to eq 6
      expect(orphan_checker.sample).
        to eq file_paths_v.
          map {|s| "/#{v_prefix}/#{s}" } +
        file_paths_n.
          map {|s| "/#{n_prefix}/#{s}" }
    end

    it "deletes the orphans" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 6
    end    
  end

  describe "two assets, one video and one image, plus two orphans" do
    let(:file_paths_v) do
      ["#{v_prefix}/#{asset_v.file_data['id']}", "video_orphan.mp4"]
    end
    let(:file_paths_n) do
       ["#{n_prefix}/#{asset_n.file_data['id']}", "image_orphan.jpg"]
    end
    it "finds the orphans" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 4
      expect(orphan_checker.orphans_found).to eq 2
      expect(orphan_checker.sample).to eq [
        "/#{v_prefix}/video_orphan.mp4",
        "/#{n_prefix}/image_orphan.jpg"
      ]
    end
    it "deletes the orphans" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 2
    end
  end
end