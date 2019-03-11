require 'rails_helper'

RSpec.describe Importers::FileSetImporter do
  let(:test_file_path) { Rails.root.join("spec/test_support/images/20x20.png")}
  let(:test_file_sha1) { Digest::SHA1.hexdigest(File.read(test_file_path)) }
  let(:fake_test_file_url) { "http://www.example.com/fedora/rest/prod/n5/83/xw/08/n583xw08g/files/file_hash" }

  # not giving it a file_url, so it won't try to import it from fedora, cause we're
  # not ready to test that here.
  let(:metadata) do
    {
        "id" => "n583xw08g",
        "label" => "b10371138_367.tif",
        "import_url" => "https://scih-uploads.s3.amazonaws.com/b10371138/b10371138_367.tif",
        "creator" => [
            "njoniec@sciencehistory.org"
        ],
        "depositor" => "njoniec@sciencehistory.org",
        "title" => [
            "b10371138_367.tif"
        ],
        "date_uploaded" => "2018-11-29T14:09:26+00:00",
        "date_modified" => "2018-11-29T14:09:26+00:00",
        "access_control_id" => "4d4c2f66-78a3-4385-a835-765064056526",
        "file_url" => fake_test_file_url,
        "sha_1" => test_file_sha1,
        "title_for_export" => "b10371138_367.tif"
    }
  end

  before do
    stub_request(:any, fake_test_file_url).
      to_return(body: File.read(test_file_path), status: 200)
  end


  context "simple fileset" do
    let(:file_set_importer) { Importers::FileSetImporter.new(metadata) }

    it "Imports properly" do
      file_set_importer.import
      new_asset = Asset.first

      expect(new_asset.title).to match /b10371138_367/
      expect(new_asset.created_at).to eq(DateTime.parse(metadata["date_uploaded"]))
      expect(new_asset.updated_at).to eq(DateTime.parse(metadata["date_modified"]))

      expect(new_asset.stored?).to be(true)
      expect(new_asset.content_type).to eq("image/png")
      expect(new_asset.file.read).to eq(File.read(test_file_path, encoding: "BINARY"))
      expect(new_asset.sha1).to eq(test_file_sha1)
    end

    describe "with existing item with same bytestream", queue_adapter: :inline do
      let!(:existing_item) do
        FactoryBot.create(:asset, friendlier_id: metadata["id"], title: "old title", file: File.open(test_file_path)).tap do |item|
          item.reload
          expect(item.sha1).to eq(test_file_sha1)
        end
      end

      it "imports and updates data, without re-importing file" do
        expect(file_set_importer).not_to receive(:assign_import_bytestream)
        file_set_importer.import

        expect(Asset.where(friendlier_id: metadata["id"]).count).to eq(1)
        item = Asset.find_by_friendlier_id!(metadata["id"])

        expect(item.title).to eq "b10371138_367.tif"
        expect(item.content_type).to eq("image/png")
        expect(item.file.read).to eq(File.read(test_file_path, encoding: "BINARY"))
        expect(item.sha1).to eq(test_file_sha1)
      end
    end

    describe "with existing item with different bytestream", queue_adapter: :inline do
      let(:other_file_path) { Rails.root.join("spec/test_support/images/30x30.png")}

      let!(:existing_item) do
        FactoryBot.create(:asset, friendlier_id: metadata["id"], title: "old title", file: File.open(other_file_path)).tap do |item|
          item.reload
          expect(item.file.present?).to be(true)
          expect(item.sha1).to be_present
          expect(item.sha1).not_to eq(test_file_sha1)
        end
      end

      it "imports and updates data, replacing file" do
        previous_stored_file = existing_item.file
        expect(previous_stored_file.exists?).to be(true)

        expect(file_set_importer).to receive(:assign_import_bytestream).and_call_original
        file_set_importer.import

        expect(Asset.where(friendlier_id: metadata["id"]).count).to eq(1)
        item = Asset.find_by_friendlier_id!(metadata["id"])

        expect(item.title).to eq "b10371138_367.tif"

        expect(item.content_type).to eq("image/png")
        expect(item.file.read).to eq(File.read(test_file_path, encoding: "BINARY"))
        expect(item.sha1).to eq(test_file_sha1)

        # deleted previous file
        expect(previous_stored_file.exists?).not_to be(true)
      end
    end
  end
end
