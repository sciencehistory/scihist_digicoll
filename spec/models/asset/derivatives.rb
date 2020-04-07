require 'rails_helper'

describe "derivative creation" do
  let(:pdf_file_path) { Rails.root.join("spec/test_support/pdf/sample.pdf")}
  let(:pdf_file_sha512) { Digest::SHA512.hexdigest(File.read(pdf_file_path)) }
  let!(:pdf_asset) { FactoryBot.create(:asset, file: File.open(pdf_file_path)) }
  it "creates pdf derivatives" do
    pdf_asset.file.metadata['sha512'] = pdf_file_sha512
    pdf_asset.save!
    pdf_asset.create_derivatives
    expect(pdf_asset.derivatives.pluck('key').sort).
      to contain_exactly("thumb_large","thumb_large_2X",
        "thumb_mini", "thumb_mini_2X",
        "thumb_standard", "thumb_standard_2X"
      )
    widths = Hash[pdf_asset.derivatives.
      collect { |d| [d.key.to_sym, d.file_data['metadata']['width']] }]

    expect(widths[:thumb_mini]).to eq(54)
    expect(widths[:thumb_large_2X]).to eq(1050)
  end
end