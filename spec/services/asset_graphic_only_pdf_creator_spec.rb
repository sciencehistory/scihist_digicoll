require 'rails_helper'
require 'pdf-reader'

# This is kind of slow becuase we use real files and real processing to make sure
# we're testing real life, mocking would take us too fake to be testing reality.
#
describe AssetGraphicOnlyPdfCreator, type: :model do
  let(:creator) { AssetGraphicOnlyPdfCreator.new(asset) }
  let(:tiff_path) { Rails.root + "spec/test_support/images/mini_page_scan.tiff" }

  # get width/height/dpi of original, we're actually going to look it up live,
  # which is slow, but we need to get this right.
  let(:tiff_characteristics) {
    out, err = TTY::Command.new(printer: :null).run(
      "mediainfo",
      tiff_path,
      "--output=JSON"
    )

    json = JSON.parse(out)
    img_data = json["media"]["track"].find {|track| track["@type"] == "Image" }

    # return hash
    {
      height: Integer(img_data["Height"]).to_f,
      width:  Integer(img_data["Width"]).to_f,
      dpi: Integer(img_data["extra"]["Density_X"]).to_f
    }
  }

  let(:asset) { create(:asset, :inline_promoted_file, file: File.open(tiff_path)) }

  it "creates a PDF" do
    pdf_file = creator.create

    pdf = PDF::Reader.new(pdf_file.path)

    expect(pdf.page_count).to eq 1
    page = pdf.pages.first

    # is height and width as expected for correct dpi? PDF uses 72dpi units
    width_inches = tiff_characteristics[:width] / tiff_characteristics[:dpi]
    height_inches = tiff_characteristics[:height] / tiff_characteristics[:dpi]

    expect(page.width / 72).to be_within(0.01).of(width_inches)
    expect(page.height / 72).to be_within(0.01).of(height_inches)

    # NO text!
    expect(page.text).not_to be_present

    # no great way apparently to make sure it includes an image!

    pdf_file.unlink
  end
end
