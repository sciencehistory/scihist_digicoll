require 'rails_helper'

describe RightsIconDisplay, type: :decorator do
  describe "with nil rights statement" do
    let(:work) { build(:work, rights: nil)}

    it "returns empty string" do
      expect(RightsIconDisplay.new(work).display).to eq("")
    end
  end


  describe "with empty string rights statement" do
    let(:work) { build(:work, rights: "")}

    it "returns empty string" do
      expect(RightsIconDisplay.new(work).display).to eq("")
    end
  end

  describe "public domain item" do
    let(:work) { build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")}
    let(:rendered) { Nokogiri::HTML.fragment( RightsIconDisplay.new(work).display ) }

    it "renders" do
      link = rendered.at_xpath("./a")
      expect(link).to be_present

      expect(link["class"].split(" ")).to match(['rights-statement', 'large'])

      expect(link["href"]).to eq(work.rights)
      expect(link).to have_selector("img.rights-statement-logo[src*='rightsstatements-NoC.Icon-Only.dark']")

      expect(link.inner_html).to include("Public<br>Domain")
    end
  end

  describe "dropdown-item mode" do
    let(:work) { build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")}
    let(:rendered) { Nokogiri::HTML.fragment( RightsIconDisplay.new(work, mode: :dropdown_item).display ) }

    it "renders" do
      link = rendered.at_xpath("./a")
      expect(link).to be_present

      expect(link["class"].split(" ")).to match(['rights-statement', 'dropdown-item'])

      expect(link["href"]).to eq(work.rights)
      expect(link).to have_selector("img.rights-statement-logo[src*='rightsstatements-NoC.Icon-Only.dark']")

      expect(link.inner_html).to include("Public Domain")
    end
  end

end
