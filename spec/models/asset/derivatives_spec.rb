require 'rails_helper'

describe "derivative creation" do
  let!(:pdf_asset) { create(:asset_with_faked_file, :pdf, faked_derivatives: {}) }
  it "creates pdf derivatives" do
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