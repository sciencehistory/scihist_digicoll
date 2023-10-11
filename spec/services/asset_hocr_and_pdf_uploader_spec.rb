require 'rails_helper'
# AssetHocrAndPdfUploader.new(@asset).attach(
#   hocr: params[:hocr],
#   textonly_pdf: params[:textonly_pdf])

describe AssetHocrAndPdfUploader, type: :model do
  let(:parent_work) { create(:work, published: false) }
  let(:asset) {  create(:asset, parent: parent_work, hocr:nil) }

  let(:uploader_result) { AssetHocrAndPdfUploader.new(asset).attach(hocr: hocr, textonly_pdf: pdf) }
  let(:hocr) {
    Rack::Test::UploadedFile.new(Rails.root + "spec/test_support/hocr_xml/hocr.xml",          "application/xml") }
  let(:bad_hocr)   {
    Rack::Test::UploadedFile.new(Rails.root + "spec/test_support/ohms_xml/smythe_OH0042.xml", "application/xml") }
  let(:pdf)  {
    Rack::Test::UploadedFile.new(Rails.root + "spec/test_support/pdf/textonly.pdf",           "application/xml") }
  let(:bad_pdf)    {
    Rack::Test::UploadedFile.new(Rails.root + "spec/test_support/pdf/tiny.pdf",               "application/xml") }

  context "valid files" do
    it "attaches the files" do
      expect(uploader_result).to be true
      expect(asset.hocr).to include "ocr_line"
      expect(asset.suppress_ocr).to be false
      deriv = asset.file_derivatives[:textonly_pdf]
      expect(deriv).to be_present
      expect(deriv).to be_a AssetUploader::UploadedFile
      expect(deriv.size).to eq 7075
      expect(deriv.metadata).to be_present
    end
  end

  context "pdf missing" do
    let(:pdf)  { nil }
    it "raises" do
      expect { uploader_result }.to raise_error(
        AssetHocrAndPdfUploaderError,
        "Please provide a textonly_pdf and an hocr.")
    end
  end

  context "hocr missing" do
    let(:hocr) {nil}
    it "raises" do
      expect { uploader_result }.to raise_error(
        AssetHocrAndPdfUploaderError,
        "Please provide a textonly_pdf and an hocr.")
    end
  end

  context "bad hocr" do
    let(:hocr) { bad_hocr }
    it "raises" do
      expect { uploader_result }.to raise_error(
        AssetHocrAndPdfUploaderError,
        "This HOCR file isn't valid.")
    end
  end

  context "bad pdf" do
    let(:pdf)  { bad_pdf }
    it "raises" do
      expect { uploader_result }.to raise_error(
        AssetHocrAndPdfUploaderError,
        "This PDF isn't valid.")
    end
  end

  context "asset already has pdf" do
    let(:asset) { create(:asset_with_faked_file,
      faked_derivatives: { textonly_pdf: FactoryBot.build(:stored_uploaded_file, content_type: "application/pdf") },
      hocr: hocr
      )
    }
    it "replaces it with the new pdf" do
      expect(asset.file_derivatives[:textonly_pdf].metadata["size"]).to eq 2750
      expect(uploader_result).to be true
      expect(asset.reload.file_derivatives[:textonly_pdf].metadata["size"]).to eq 7075
    end
  end
end
