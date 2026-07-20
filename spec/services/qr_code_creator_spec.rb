require 'rails_helper'
require 'chunky_png'

# Uses real rqrcode encoding and real ChunkyPNG compositing (no mocking) so
# we're testing actual output.
describe QrCodeCreator do
  let(:url) { "https://digital.sciencehistory.org/works/abc123" }
  let(:icon_path) { Rails.root.join("spec/test_support/images/30x30.png").to_s }

  describe "without an icon" do
    it "produces a valid, square, black-and-white PNG QR code" do
      img = described_class.new(url).call

      expect(img).to be_a(ChunkyPNG::Image)
      expect(img.width).to be > 0
      expect(img.height).to eq(img.width) # QR codes are square

      # A plain QR is strictly black and white -- no icon compositing happened.
      expect(img.pixels.uniq).to contain_exactly(ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE)

      # And it round-trips to a valid PNG blob.
      expect(ChunkyPNG::Image.from_blob(img.to_blob).dimension).to eq(img.dimension)
    end
  end

  describe "with an icon" do
    it "composites the (colored) icon into the center of a valid, square PNG" do
      img = described_class.new(url, icon_path: icon_path).call

      expect(img).to be_a(ChunkyPNG::Image)
      expect(img.width).to be > 0
      expect(img.height).to eq(img.width)

      # The composited icon introduces colors beyond the plain QR's black/white,
      # proving the icon actually made it onto the code.
      colors = img.pixels.uniq
      expect(colors.length).to be > 2
      expect(colors).not_to contain_exactly(ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE)

      # And it lands in the middle: the central region contains icon colors,
      # rather than being only plain black/white QR modules.
      bw = [ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE]
      qx, qy = img.width / 4, img.height / 4
      center_colors = (qx...(qx * 3)).flat_map { |x| (qy...(qy * 3)).map { |y| img[x, y] } }.uniq
      expect(center_colors - bw).not_to be_empty
    end
  end
end
