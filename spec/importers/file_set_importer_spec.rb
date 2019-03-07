require 'rails_helper'

RSpec.describe Importers::FileSetImporter do
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
        "file_url" => "http://www.example.com/fedora/rest/prod/n5/83/xw/08/n583xw08g/files/file_hash",
        "sha_1" => "1fac2923901895582e0406bfa40779a662d1010e",
        "title_for_export" => "b10371138_367.tif"
    }
  end

  context "Import fileset" do
    # we're not testing bytestream import yet
    context "simple fileset without bytestream" do
      let(:file_set_importer) { Importers::FileSetImporter.new(metadata, disable_bytestream_import: true) }

      it "Imports properly" do
        file_set_importer.save_item()
        expect(Asset.first.title).to match /b10371138_367/
      end
    end
  end
end
