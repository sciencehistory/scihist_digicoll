require 'rails_helper'

describe DownloadOption do
  describe ".with_formatted_subhead" do
    it "formats with everything" do
      expect(DownloadOption.with_formatted_subhead(
        "something",
        work_friendlier_id: "work_id",
        url: "http://example.org",
        content_type: "image/jpeg",
        width: 100,
        height: 200,
        size: 16384).subhead).to eq "JPEG — 100 x 200px — 16 KB"
    end

    it "formats with no content-type" do
      expect(DownloadOption.with_formatted_subhead(
        "something",
        work_friendlier_id: "work_id",
        url: "http://example.org",
        width: 100,
        height: 200,
        size: 16384).subhead).to eq "100 x 200px — 16 KB"
    end

    it "formats with no dimensions" do
      expect(DownloadOption.with_formatted_subhead(
        "something",
        work_friendlier_id: "work_id",
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
    let(:work_friendlier_id) { "work-id" }
    let(:download_option) { DownloadOption.new(label, work_friendlier_id: work_friendlier_id, url: url, subhead: subhead, analyticsAction: analyticsAction) }

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

  describe "analytics data- attributes" do
    let(:analyticsAction) { "click-on-something" }
    let(:work_friendlier_id) { "work-id" }

    let(:download_option) {
      DownloadOption.new("some label", work_friendlier_id: work_friendlier_id, analyticsAction: analyticsAction, url: "#")
    }

    it "are included in data_attrs" do
      expect(download_option.data_attrs[:analytics_category]).to eq "Work"
      expect(download_option.data_attrs[:analytics_action]).to eq analyticsAction
      expect(download_option.data_attrs[:analytics_label]).to eq work_friendlier_id
    end
  end

  describe "turnstile protect data attribute" do
    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:cf_turnstile_downloads_enabled).and_return(true)
    end

    it "is automatically included for analyticsAction download_original" do
      download_option = DownloadOption.new("some label", work_friendlier_id: "work-id", analyticsAction: "download_original", url: "#")
      expect(download_option.data_attrs[:turnstile_protection]).to eq "true"
    end

    it "but not with content-type pdf" do
      download_option = DownloadOption.new("some label", content_type: "application/pdf", work_friendlier_id: "work-id", analyticsAction: "download_original", url: "#")
      expect(download_option.data_attrs[:turnstile_protection]).to be_nil
    end
  end

end
