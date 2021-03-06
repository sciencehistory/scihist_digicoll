require 'rails_helper'

describe DziFiles do
  let(:asset) { create(:asset_with_faked_file) }
  let(:dzi_management) { DziFiles.new(asset) }

  describe "create and delete" do
    it "creates and deletes and does everything" do
      dzi_management.create
      expect(dzi_management.exists?).to be true
      expect(dzi_management.url).to be_present

      # let's make sure at least something is in the _files dir, although
      # we aren't gonna test for every tile.
      uploaded_file_0_0 = Shrine::UploadedFile.new(
        "id"    => "#{dzi_management.base_file_path}_files/0/0_0.jpg",
        "storage" => dzi_management.shrine_storage_key
      )
      expect(uploaded_file_0_0.exists?).to be true

      dzi_management.delete
      expect(dzi_management.exists?).to be false
      expect(uploaded_file_0_0.exists?).to be false
    end
  end

  describe "Asset life-cycle automatic actions", queue_adapter: :test do
    describe "asset creation" do
      let(:asset) { create(:asset, :inline_promoted_file, :bg_derivatives)}

      it "queues dzi creation" do
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

    describe "asset deletion" do
      let(:asset) { create(:asset_with_faked_file) }

      it "queues dzi deletion" do
        asset.destroy
        expect(DeleteDziJob).to have_been_enqueued.with(asset.dzi_file.dzi_uploaded_file.id)
      end

      it "respects disabled promotion_directive" do
        asset.set_promotion_directives(delete: false)
        asset.destroy
        expect(DeleteDziJob).not_to have_been_enqueued
      end

      it "respects inline promotion_directive" do
        asset.set_promotion_directives(delete: :inline)
        asset.destroy
        expect(DeleteDziJob).not_to have_been_enqueued
        expect(asset.dzi_file.exists?).to be false
      end
    end

    describe "asset file change" do
      let(:asset) {
        create(:asset_with_faked_file, faked_file: File.open((Rails.root + "spec/test_support/images/30x30.png").to_s)).
        tap {|a| a.dzi_file.create }
      }

      it "deletes original and creates new" do
        asset.set_promotion_directives(promote: :inline)
        original_dzi_id = asset.dzi_file.dzi_uploaded_file.id

        asset.file = File.open((Rails.root + "spec/test_support/images/30x30.jpg").to_s)
        asset.save!

        expect(DeleteDziJob).to have_been_enqueued.once.with(original_dzi_id)
        expect(CreateDziJob).to have_been_enqueued.once.with(asset)
      end
    end

    describe "non-image file" do
      describe "asset creation" do
        let(:asset) {
          create(:asset_with_faked_file, faked_content_type: "audio/mpeg", faked_file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3").to_s))
        }

        it "does not queue dzi creation" do
          expect {
            asset.dzi_file.create
          }.to raise_error(ArgumentError)

          expect(CreateDziJob).not_to have_been_enqueued.with(asset)
        end
      end

      describe "asset deletion" do
        let(:asset) { create(:asset_with_faked_file, faked_content_type: "audio/mpeg", faked_file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3").to_s)) }

        it "does not raise" do
          asset.set_promotion_directives(delete: :inline)
          asset.destroy
        end
      end
    end
  end

  # normally shouldn't happen
  describe "without attached file", queue_adapter: :inline do
    let(:asset) { create(:asset) }
    it "can be deleted without complaining about missing DZI/md5" do
      asset.destroy!
      expect(asset.destroyed?).to be(true)
    end

    it "can have a file assigned, and get DZI's, without complaining" do
      asset.file = File.open(Rails.root + "spec/test_support/images/20x20.png")
      asset.save!
      asset.reload
      expect(dzi_management.exists?).to eq true
    end
  end
end
