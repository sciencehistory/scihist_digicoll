require 'rails_helper'

# This test fails part of the time unless you skip it.
# If you can't get it to fail in development,
# edit .github/workflows/ci.yml as follows:
#
#        - name: Run tests
#          run: |
#            for i in {1..10}; do echo "try $i" && bundle exec rspec spec/factory_specs/asset_factory_spec.rb; done
#
describe "inline_promoted_file asset factory: file is present" do
  let(:asset_1)  {
    create(:asset, :inline_promoted_file,
      file: File.open((Rails.root + "spec/test_support/images/20x20.png"))
    )
  } 
  let(:path_1) {
    Rails.root + 'public' +
    ScihistDigicoll::Env.shrine_store_storage.prefix +
    asset_1.file_data['id']
  }

  let(:asset_2)  {
    create(:asset, :inline_promoted_file,
      file: File.open((Rails.root + "spec/test_support/video/sample_video.mp4"))
    )
  }
  let(:path_2) {
    Rails.root + 'public' +
    ScihistDigicoll::Env.shrine_store_video_storage.prefix +
    asset_2.file_data['id']
  }
    
  it "when the first example starts" do
    skip
    expect(File.file?(path_1)).to be true
    expect(File.file?(path_2)).to be true
  end

  it "when the second example starts" do
    skip
    expect(File.file?(path_1)).to be true
    expect(File.file?(path_2)).to be true
  end
end