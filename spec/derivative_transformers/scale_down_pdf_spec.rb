require 'rails_helper'
require 'marcel'

describe ScaleDownPdf do
  let(:original_path) { Rails.root + "spec/test_support/pdf/sample-text-and-image-small.pdf"}
  let(:original_file) { File.open(original_path) }

  it "creates an output PDF" do
    output_file = ScaleDownPdf.new.call(original_file)

    expect(output_file).to be_kind_of(Tempfile)

    # In some cases such as this it won't really be smaller cause we already were 72 dpi,
    # but I think it shouldn't be bigger?
    expect(output_file.size).to be <= original_file.size

    expect(Marcel::MimeType.for(output_file)).to eq "application/pdf"

    output_file.close
    output_file.unlink
  end
end
