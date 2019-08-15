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

  describe "#as_json" do
    let(:url) { "http://example.org/faked" }
    let(:subhead) { "This is a <small>subhead</small>" }
    let(:label) { "This is a label" }
    let(:analyticsAction) { "click-on-something" }
    let(:download_option) { DownloadOption.new(label, url: url, subhead: subhead, analyticsAction: analyticsAction) }

    it "produces hash" do
      expect(download_option.as_json).to match({
        url: url,
        subhead: subhead,
        label: label,
        analyticsAction: analyticsAction
      })
    end

    it "produces string from to_json" do
      expect(JSON.parse(download_option.to_json)).to match({
        "url" => url,
        "subhead" => subhead,
        "label" => label,
        "analyticsAction" => analyticsAction
      })
    end
  end

end
