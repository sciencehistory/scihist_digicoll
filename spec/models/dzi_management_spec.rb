require 'rails_helper'

describe DziManagement do
  let(:asset) { create(:asset_with_faked_file) }
  let(:dzi_management) { DziManagement.new(asset) }

  describe "#create" do
    it "creates DZI files on appropriate storage, with UploadedFile access" do
      dzi_management.create
      expect(dzi_management.exists?).to be true
      expect(dzi_management.url).to be_present

      # let's make sure at least something is in the _files dir, although
      # we aren't gonna test for every tile.
      uploaded_file_0_0 = Shrine::UploadedFile.new(
        "id"    => "#{dzi_management.base_file_name}_files/0/0_0.jpg",
        "storage" => dzi_management.shrine_storage_key
      )
      expect(uploaded_file_0_0.exists?).to be true
    end
  end
end
