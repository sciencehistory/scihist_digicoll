require 'rails_helper'

describe "derivative creation" do
  let(:pdf_file_path) { Rails.root.join("spec/test_support/pdf/sample.pdf")}
  let(:pdf_file_sha512) { Digest::SHA512.hexdigest(File.read(pdf_file_path)) }
  let!(:pdf_asset) { FactoryBot.create(:asset, file: File.open(pdf_file_path)) }
  it "creates pdf derivatives" do
    pdf_asset.file.metadata['sha512'] = pdf_file_sha512
    pdf_asset.save!
    pdf_asset.create_derivatives
    expect(pdf_asset.file_derivatives.keys.sort).
      to contain_exactly(:thumb_large,:thumb_large_2X,
        :thumb_mini, :thumb_mini_2X,
        :thumb_standard, :thumb_standard_2X
      )
    expect(pdf_asset.file_derivatives[:thumb_mini].metadata['width']).to eq(54)
    expect(pdf_asset.file_derivatives[:thumb_large_2X].metadata['width']).to eq(1050)
  end
end