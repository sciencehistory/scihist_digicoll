require 'rails_helper'

describe S3PathIterator do
  let (:it_1) do
    S3PathIterator.new(
      shrine_storage: ScihistDigicoll::Env.shrine_store_storage,
      extra_prefix: 'asset', show_progress_bar: false)
  end
  let (:it_2) do
    S3PathIterator.new(
      shrine_storage: ScihistDigicoll::Env.shrine_store_video_storage,
      extra_prefix: 'asset', show_progress_bar: false )
  end

  before do
    allow_any_instance_of(S3PathIterator).to receive(:s3_bucket_name).and_return('arbitrary string')
    # Regular storage:
    allow(it_1).to receive(:s3_client).and_return(AwsHelpers::MockAwsClient.new(paths: file_paths_1).client)
    # Video storage:
    allow(it_2).to receive(:s3_client).and_return(AwsHelpers::MockAwsClient.new(paths: file_paths_2).client)
  end

  describe "Two path iterators pointed at two different local buckets" do
    let(:file_paths_1) { ['aaa', 'bbb', 'ccc'] }
    let(:file_paths_2) { ['ddd', 'eee', 'fff'] }

    it "It's possible to feed fake paths to the iterators" do
      s3_keys_found_1 = []
      it_1.each_s3_path { |s3_key| s3_keys_found_1 << s3_key }
      expect(s3_keys_found_1).to eq ["aaa", "bbb", "ccc"]

      s3_keys_found_2 = []
      it_2.each_s3_path { |s3_key| s3_keys_found_2 << s3_key }
      expect(s3_keys_found_2).to eq ["ddd", "eee", "fff"]
    end
  end

  describe "Using actual files" do
    let!(:asset_1)  { create(:asset, :inline_promoted_file,
        position: 1,
        file: File.open((Rails.root + "spec/test_support/images/20x20.png"))
      )
    }
    let!(:asset_2)  { create(:asset, :inline_promoted_file,
        position: 2,
        file: File.open((Rails.root + "spec/test_support/images/20x20.png"))
      )
    }
    let!(:work) { FactoryBot.create( :public_work, members: [asset_1, asset_2]) }
    let(:file_paths_1) { [work.members.first.file_data["id"], work.members.second.file_data["id"]] }
    let(:file_paths_2) { [] }
    
    it "is possible to feed real paths to the iterators" do
      an_asset = work.members[0]
      s3_keys_found_1 = []
      it_1.each_s3_path { |s3_key| s3_keys_found_1 << s3_key }
      expect(s3_keys_found_1).to eq file_paths_1

      s3_keys_found_2 = []
      it_2.each_s3_path { |s3_key| s3_keys_found_2 << s3_key }
      expect(s3_keys_found_2).to eq file_paths_2
    end
  end
end