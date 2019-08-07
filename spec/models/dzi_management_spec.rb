require 'rails_helper'

describe DziManagement do
  let(:asset) { create(:asset_with_faked_file) }
  let(:dzi_management) { DziManagement.new(asset) }

  describe "create and delete" do
    it "creates and deletes and does everything" do
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

      dzi_management.delete
      expect(dzi_management.exists?).to be false
      expect(uploaded_file_0_0.exists?).to be false
    end
  end

  describe "Asset life-cycle automatic actions", queue_adapter: :test do
    let(:asset) { create(:asset, :inline_promoted_file, :bg_derivatives)}

    describe "asset creation", queue_adapter: :test do
      it "creates dzi" do
        asset
        expect(CreateDziJob).to have_been_enqueued.with(asset)
      end
      describe "with derivatives off" do
        let(:asset) { create(:asset, :inline_promoted_file, :no_derivatives_creation)}
        it "does not create dzi" do
          asset
          expect(CreateDziJob).not_to have_been_enqueued.with(asset)
        end
      end
    end
  end
end
