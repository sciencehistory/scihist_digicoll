require "rails_helper"

describe DetectWhiteImageEdge do
  let(:service) { described_class.new }

  describe "png without white border" do
    let(:image_path) { Rails.root + "spec/test_support/images/30x30.png" }

    it "detects false" do
      expect(service.call(image_path)).to eq false
    end
  end

  describe "jpg without white border" do
    let(:image_path) { Rails.root + "spec/test_support/images/30x30.jpg" }

    it "detects false" do
      expect(service.call(image_path)).to eq false
    end
  end

  describe "tiff without white border" do
    let(:image_path) { Rails.root + "spec/test_support/images/mini_page_scan.tiff" }

    it "detects false" do
      expect(service.call(image_path)).to eq false
    end
  end

  describe "tiff with white border" do
    let(:image_path) { Rails.root + "spec/test_support/images/white_border_scan_80px.tiff" }

    it "detects true" do
      expect(service.call(image_path)).to eq true
    end
  end

  describe "jpg with white border" do
    let(:image_path) { Rails.root + "spec/test_support/images/white_border_scan_80px.jpg" }

    it "detects true" do
      expect(service.call(image_path)).to eq true
    end
  end

  describe "png with white border" do
    let(:image_path) { Rails.root + "spec/test_support/images/white_border_scan_80px.png" }

    it "detects true" do
      expect(service.call(image_path)).to eq true
    end
  end
end
