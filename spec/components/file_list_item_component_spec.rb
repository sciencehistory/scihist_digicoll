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
end
