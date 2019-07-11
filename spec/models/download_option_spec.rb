require 'rails_helper'

describe DownloadOption do
  describe ".with_formatted_subhead" do
    it "formats with everything" do
      expect(DownloadOption.with_formatted_subhead(
        "something",
        url: "http://example.org",
        content_type: "image/jpeg",
        width: 100,
        height: 200,
        size: 16384).subhead).to eq "JPEG — 100 x 200px — 16 KB"
    end

    it "formats with no content-type" do
      expect(DownloadOption.with_formatted_subhead(
        "something",
        url: "http://example.org",
        width: 100,
        height: 200,
        size: 16384).subhead).to eq "100 x 200px — 16 KB"
    end

    it "formats with no dimensions" do
      expect(DownloadOption.with_formatted_subhead(
        "something",
        url: "http://example.org",
        height: nil,
        width: nil,
        content_type: "image/jpeg",
        size: 16384).subhead).to eq "JPEG — 16 KB"
    end
  end
end
