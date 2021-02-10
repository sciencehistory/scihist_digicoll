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
      container = rendered.at_css("div.rights-statement")
      expect(container).to be_present

      expect(container["class"].split(" ")).to match(['rights-statement', 'large', 'rights-statements-org'])

      expect(container).to have_selector("img.rights-statement-logo[src*='rightsstatements-NoC.Icon-Only.dark']")


      link = container.at_css("a")
      expect(link).to be_present
      expect(link["href"]).to eq(work.rights)
      expect(link.inner_html).to include("Public<br>Domain")
    end
  end

  describe "dropdown-item mode" do
    let(:work) { build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")}
    let(:rendered) { Nokogiri::HTML.fragment( RightsIconDisplay.new(work, mode: :dropdown_item).display ) }

    it "renders" do
      link = rendered.at_xpath("./a")
      expect(link).to be_present

      expect(link["class"].split(" ")).to match(['rights-statement', 'dropdown-item', 'rights-statements-org'])

      expect(link["href"]).to eq(work.rights)
      expect(link).to have_selector("img.rights-statement-logo[src*='rightsstatements-NoC.Icon-Only.dark']")

      expect(link.inner_html).to include("Public Domain")
    end
  end

  describe "CC license" do
    let(:work) { build(:work, rights: "https://creativecommons.org/licenses/by-nc-nd/4.0/")}
    let(:rendered) { Nokogiri::HTML.fragment( RightsIconDisplay.new(work).display ) }

    it "renders" do
      container = rendered.at_css("div.rights-statement")
      expect(container).to be_present

      expect(container["class"].split(" ")).to match(['rights-statement', 'large', 'creative-commons-org'])
      expect(container).to have_selector("img.rights-statement-logo[src*='cc']")

      expect(container.inner_text).to include("This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.")

      link = container.at_css("a")
      expect(link).to be_present
      expect(link["href"]).to eq(work.rights)
      expect(link.inner_html).to include("Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.")
    end

    context "dropdown-item mode" do
      let(:rendered) { Nokogiri::HTML.fragment( RightsIconDisplay.new(work, mode: :dropdown_item).display ) }

      it "renders" do
        link = rendered.at_xpath("./a")
        expect(link).to be_present

        expect(link["class"].split(" ")).to match(['rights-statement', 'dropdown-item', 'creative-commons-org'])

        expect(link["href"]).to eq(work.rights)
        expect(link).to have_selector("img.rights-statement-logo[src*='cc']")

        expect(link.inner_html).to include("BY-NC-ND 4.0")
      end
    end
  end

end
