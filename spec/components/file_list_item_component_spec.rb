require 'rails_helper'

describe FileListItemComponent, type: :component do
  let(:rendered) { render_inline(FileListItemComponent.new(asset, index: 0)) }

  describe "PDF transcript" do
    let(:asset) { create(:asset_with_faked_file, :pdf, role: "transcript", parent: create(:work)) }

    it "renders" do
      img = rendered.at_css(".image img")
      expect(img).to be_present
      expect(img['src']).to eq asset.file_url("thumb_mini")

      title_link = rendered.at_css(".title a")
      expect(title_link.text.strip).to eq "Transcript (Published Version)"
      expect(title_link["href"]).to eq download_path(asset.file_category, asset, disposition: :inline)

      details = rendered.at_css(".details")
      expect(details.text).to include("PDF — #{ScihistDigicoll::Util.simple_bytes_to_human_string(asset.size)}")
    end
  end

  describe "FLAC audio" do
    let(:asset) { create(:asset_with_faked_file, :flac, parent: create(:work)) }

    it "links to m4a derivative download" do
      title_link = rendered.at_css(".title a")

      expect(title_link.text.strip).to eq asset.title
      expect(title_link["href"]).to eq download_derivative_path(asset, :m4a, disposition: :inline)
    end

    it "includes duration not size in details" do
      details = rendered.at_css(".details")
      expect(details.text).to include("FLAC — 00:00:05")
    end
  end

  describe "private item" do
    let(:asset) { create(:asset_with_faked_file, :pdf, published: false, parent: create(:work)) }

    it "has private badge" do
      expect(rendered).to have_selector("span.badge:contains('Private')")
    end

    describe "without show_private_badge" do
      let(:rendered) { render_inline(FileListItemComponent.new(asset, index: 0, show_private_badge: false)) }

      it "does not have private badge" do
        expect(rendered).not_to have_selector("span.badge:contains('Private')")
      end
    end
  end
end
