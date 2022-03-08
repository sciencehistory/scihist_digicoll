require 'rails_helper'

describe OrphanS3Originals do
  let!(:fake_aws_s3_client_v) { Aws::S3::Client.new(stub_responses: true) }
  let!(:fake_aws_s3_client_n) { Aws::S3::Client.new(stub_responses: true) }

  let(:asset_n)  { create(:asset, :inline_promoted_file,
      file: File.open((Rails.root + "spec/test_support/images/20x20.png"))
    )
  }
  let(:asset_v)  {
    #TODO fix this:
    sleep 0.005
    create(:asset, :inline_promoted_file,
      file: File.open((Rails.root + "spec/test_support/video/sample_video.mp4"))
    )
  }

  let!(:file_paths_v) do
    ['video/babe_ruth', 'video/steve_jobs', 'video/nelson_mandela']
  end
  let!(:file_paths_n) do
    ['normal/leo_tolstoy', 'normal/eleanor_roosevelt', 'normal/edgar_allan_poe']
  end

  let!(:fake_aws_list_output_v) do
     Aws::S3::Types::ListObjectsOutput.new(
      is_truncated: false,   marker: '',
      next_marker: nil,      name: 'non_video_bucket',
      delimiter: '/',        max_keys: 1000,
      encoding_type: 'url',
      contents: file_paths_v.map{|path| Struct.new(:key).new(path)},
      common_prefixes: []
    )
  end
  let!(:fake_aws_list_output_n) do
     Aws::S3::Types::ListObjectsOutput.new(
      is_truncated: false,   marker: '',
      next_marker: nil,      name: 'video_bucket',
      delimiter: '/',        max_keys: 1000,
      encoding_type: 'url',
      contents: file_paths_n.map{|path| Struct.new(:key).new(path)},
      common_prefixes: []
    )
  end

  let!(:orphan_checker) do
    OrphanS3Originals.new(show_progress_bar: false)
  end

  before do
    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('not really using s3')

    # Regular storage:
    fake_aws_s3_client_n.stub_responses(:list_objects_v2, fake_aws_list_output_n)
    allow(orphan_checker.nonvideo_s3_iterator).to receive(:s3_client).and_return(fake_aws_s3_client_n)

    # # Video storage:
    fake_aws_s3_client_v.stub_responses(:list_objects_v2, fake_aws_list_output_v)
    allow(orphan_checker.video_s3_iterator).to receive(:s3_client).and_return(fake_aws_s3_client_v)
    
    mute_test_output = true
    if mute_test_output
      allow_any_instance_of(S3PathIterator).to receive(:log).and_return(nil)
      allow(orphan_checker).to receive(:output_to_stderr).and_return(nil)
    end
  end

  describe "orphan checker smoke test" do
    it "smoke test" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 6
      expect(orphan_checker.orphans_found).to eq 6
    end

    it "deletes the orphans" do
      orphan_checker.delete_orphans
      expect(orphan_checker.delete_count).to eq 6
    end    
  end

  describe "two assets, one video and one image, plus two orphans" do
    let(:file_paths_v) do
      ["#{ScihistDigicoll::Env.shrine_store_video_storage.prefix}/#{asset_v.file_data['id']}", "video_orphan.mp4"]
    end
    let(:file_paths_n) do
       ["#{ScihistDigicoll::Env.shrine_store_storage.prefix}/#{asset_n.file_data['id']}", "image_orphan.jpg"]
    end
    it "not detected as orphans" do
      orphan_checker.report_orphans
      expect(orphan_checker.files_checked).to eq 4
      expect(orphan_checker.orphans_found).to eq 2
    end
  end
end