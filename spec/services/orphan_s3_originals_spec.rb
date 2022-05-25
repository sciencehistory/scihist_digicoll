require 'rails_helper'

describe OrphanS3Originals do
  let(:fake_clients) do
    {
      video:    AwsHelpers::MockS3Client.new(paths: file_paths_v).client,
      nonvideo: AwsHelpers::MockS3Client.new(paths: file_paths_n).client
    }
  end
  let(:orphan_checker) do
    OrphanS3Originals.new(show_progress_bar: false)
  end
  let(:public_dir) { Rails.root + 'public' }
  
  # Storage prefixes:
  let(:n_prefix) { ScihistDigicoll::Env.shrine_store_storage.      prefix }
  let(:v_prefix) { ScihistDigicoll::Env.shrine_store_video_storage.prefix }

  before do
    allow_any_instance_of(S3PathIterator).to receive(:log).and_return(nil)
    allow(orphan_checker).to receive(:output_to_stderr).and_return(nil)

    allow(orphan_checker.video_s3_iterator).
      to receive(:s3_client).and_return(fake_clients[:video])
    allow(orphan_checker.nonvideo_s3_iterator).
      to receive(:s3_client).and_return(fake_clients[:nonvideo])

    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('not using s3')
    
  end

  describe "two legit assets, one video and one image, plus two orphans" do
    # Two legitimate, non-orphan assets:
    let(:asset_n)  {
      create(:asset, :inline_promoted_file,
        file: File.open((Rails.root + "spec/test_support/images/20x20.png"))
      )
    }
    let(:asset_v)  {
      # Video derivatives creation has problems in test due to HLS....
      create(:asset, :inline_promoted_file, :no_derivatives_creation,
        file: File.open((Rails.root + "spec/test_support/video/sample_video.mp4"))
      )
    }

    let(:orphans) { [
      "#{File.dirname(v_prefix + asset_v.file.id)}/orphan.mp4",
      "#{File.dirname(n_prefix + asset_n.file.id)}/orphan.png"
    ] }

    # Our fake clients will return the following s3 paths:
    let(:file_paths_v) { ["#{v_prefix}/#{asset_v.file_data['id']}", orphans[0]] }
    let(:file_paths_n) { ["#{n_prefix}/#{asset_n.file_data['id']}", orphans[1]] }
    
    before do
      dummy = Rails.root + "spec/test_support/images/20x20.png"
      FileUtils.cp(dummy, public_dir + orphans[0])
      FileUtils.cp(dummy, public_dir + orphans[1])
    end  
    
    it "finds the orphans" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 4
      expect(orphan_checker.orphans_found).to eq 2
      expect(orphan_checker.sample).to eq orphans
    end

    it "deletes the orphans" do
      expect(File.file?(public_dir + orphans[0])).to be true
      expect(File.file?(public_dir + orphans[1])).to be true
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 2
      expect(File.file?(public_dir + orphans[0])).to be false
      expect(File.file?(public_dir + orphans[1])).to be false
    end
  end
end