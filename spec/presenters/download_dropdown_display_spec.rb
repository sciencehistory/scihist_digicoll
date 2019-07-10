require 'rails_helper'

describe DownloadDropdownDisplay do
  let(:asset) { build(:asset, parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")) }
  let(:rendered) { Nokogiri::HTML.fragment(DownloadDropdownDisplay.new(asset).display) }
  let(:div) { rendered.at_css("div.action-item.downloads") }

  it "renders" do
    expect(div).to be_present

    ul = div.at_css("div.dropdown-menu.download-menu")
    expect(ul).to be_present

    expect(ul).to have_selector("h3.dropdown-header", text: "Rights")
    expect(ul).to have_selector("a.rights-statement.dropdown-item", text: /Public Domain/)
  end

  describe "no rights statement" do
    let(:asset) { build(:asset, parent: build(:work)) }
    it "renders without error" do
      expect(div).to be_present
      expect(div).not_to have_selector("h3.dropdown-header", text: "Rights")
    end
  end
end
