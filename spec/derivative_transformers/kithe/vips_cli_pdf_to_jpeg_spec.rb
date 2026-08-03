require 'rails_helper'
require 'marcel'
require 'fastimage'

describe Kithe::VipsCliPdfToJpeg do
  let(:original_path) { Rails.root + "spec/test_support/pdf/sample-text-and-image-small.pdf" }
  let(:original_file) { File.open(original_path) }
  let(:max_width) { 200 }

  it "creates a jpg thumbnail of the requested width" do
    output_file = described_class.new(max_width: max_width).call(original_file)

    expect(output_file).to be_kind_of(Tempfile)
    expect(Marcel::MimeType.for(output_file)).to eq "image/jpeg"

    width, height = FastImage.size(output_file.path)
    expect(width).to eq(max_width)
    expect(height).to be > width

    output_file.close
    output_file.unlink
  end
end
