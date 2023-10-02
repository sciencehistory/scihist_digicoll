require 'rails_helper'

# Yeah, the asset factory is such a pain we need to spec it. In the future we should probably have
# kithe supply re-usable factories.
describe "FactoryBot Asset factory" do
  describe ":asset_with_faked_file" do

    describe "without derivatives" do
      it "can build" do
        asset = FactoryBot.build(:asset_with_faked_file, faked_derivatives: {})


        expect(asset).to be_present
        expect(asset.persisted?).to be(false)
        expect(asset.file).to be_present
        expect(asset.file.exists?).to be(true)
        expect(asset.file.size > 0).to be(true)
      end

      it "can create" do
        asset = FactoryBot.create(:asset_with_faked_file, faked_derivatives: {})

        expect(asset).to be_present
        expect(asset.persisted?).to be(true)
        expect(asset.file).to be_present
        expect(asset.file.exists?).to be(true)
        expect(asset.file.size > 0).to be(true)
      end
    end

    describe "with default derivatives" do
      it "can build" do
        asset = FactoryBot.build(:asset_with_faked_file)

        expect(asset).to be_present
        expect(asset.persisted?).to be(false)

        expect(asset.file_derivatives).to be_present

        [ "thumb_mini", "thumb_mini_2X", "thumb_large", "thumb_large_2X", "thumb_standard",
          "thumb_standard_2X", "download_large", "download_medium",
          "download_full"].each do |key|
            deriv = asset.file_derivatives[key.to_sym]

            expect(deriv).to be_present
            expect(deriv.exists?).to be(true)
            expect(deriv.size > 0).to be(true)
            expect(deriv.metadata).to be_present

            expect(deriv).to be_kind_of(AssetUploader::UploadedFile)
        end
      end

      describe "with_ocr" do
        let(:asset) { FactoryBot.build(:asset_with_faked_file, :with_ocr) }

        it "includes OCR attributes and data" do
          expect(asset.hocr).to be_present
          expect(asset.file_derivatives[:textonly_pdf]).to be_present
        end
      end
    end

    describe "with specified derivatives hash" do
      it "can build" do
        asset = FactoryBot.build(:asset_with_faked_file,
                  faked_derivatives: {
                    jpeg: FactoryBot.build(:stored_uploaded_file, content_type: "image/jpeg"),
                    pdf: FactoryBot.build(:stored_uploaded_file, content_type: "application/pdf"),
                  })

        expect(asset).to be_present
        expect(asset.persisted?).to be(false)

        expect(asset.file_derivatives.count).to eq(2)
        expect(asset.file_derivatives[:jpeg].content_type).to eq("image/jpeg")
        expect(asset.file_derivatives[:pdf].content_type).to eq("application/pdf")
      end
    end
  end
end
