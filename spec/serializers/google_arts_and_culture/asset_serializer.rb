require 'rails_helper'

RSpec.describe GoogleArtsAndCulture::AssetSerializer do

  let(:column_counts) do
    {
      "subject" => 4,
      "external_id" => 2,
      "additional_title" => 1,
      "genre" => 2,
      "creator" => 2,
      "medium" => 0,
      "extent" => 2,
      "place" => 1,
      "format" => 2
    }
  end
  
  let(:attribute_keys) do
    [
      :friendlier_id,
      :subitem_id,
      :order_id,
      :title,
      :additional_title,
      :file_name,
      :filetype,
      :url_text,
      :url,
      :creator,
      :publisher,
      :subject,
      :extent,
      :min_date,
      :max_date,
      :date_of_work,
      :place,
      :medium,
      :genre,
      :description,
      :rights,
      :rights_holder
    ]
  end

  let(:asset) { create(:asset_with_faked_file, faked_content_type: "image/tiff", position: 0, friendlier_id: "abc", parent: create(:work)) }

  let(:serializer) { described_class.new(asset, attribute_keys:attribute_keys, column_counts:column_counts) }

  describe "#filename" do
    it "returns a string filename for the given asset" do
      pp serializer.class
      expect(serializer.filename).to eq "test_title_#{asset.parent.friendlier_id}_0_#{asset.friendlier_id}.jpg"
    end
  end

  describe "#filetype" do
    it "uses Image for tiff assets" do
      expect(serializer.filetype).to eq "Image"
    end
  end
  
  describe "#file" do
    it "returns an uploaded file" do
      expect(serializer.file.class).to eq AssetUploader::UploadedFile
    end
  end    
end
