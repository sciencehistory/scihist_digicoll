require 'rails_helper'

describe RightsIconComponent, type: :component do
  describe "with nil rights statement" do
    it "returns empty string" do
      expect(render_inline(RightsIconComponent.new(rights_id: nil)).to_html).to eq("")
    end
  end


  describe "with empty string rights statement" do
    it "returns empty string" do
      expect(render_inline(RightsIconComponent.new(rights_id: "")).to_html).to eq("")
    end
  end

  describe "public domain item" do
    let(:rights_id) { "http://creativecommons.org/publicdomain/mark/1.0/" }
    let(:rendered) {  render_inline(RightsIconComponent.new(rights_id: rights_id)) }

    it "renders" do
      container = rendered.at_css("div.rights-statement")
      expect(container).to be_present

      expect(container["class"].split(" ")).to match(['rights-statement', 'large', 'rights-statements-org'])

      expect(container).to have_selector("img.rights-statement-logo[src*='rightsstatements-NoC.Icon-Only.dark']")


      link = container.at_css("a")
      expect(link).to be_present
      expect(link["href"]).to eq(rights_id)
      expect(link.inner_html).to include("Public<br>Domain")
    end

    describe "dropdown-item mode" do
      let(:rights_id) { "http://creativecommons.org/publicdomain/mark/1.0/" }
      let(:rendered) { render_inline(RightsIconComponent.new(rights_id: rights_id, mode: :dropdown_item)) }

      it "renders" do
        link = rendered.at_xpath("./a")
        expect(link).to be_present

        expect(link["class"].split(" ")).to match(['rights-statement', 'dropdown-item', 'rights-statements-org'])

        expect(link["href"]).to eq(rights_id)
        expect(link).to have_selector("img.rights-statement-logo[src*='rightsstatements-NoC.Icon-Only.dark']")

        expect(link.inner_html).to include("Public Domain")
      end
    end
  end

  describe "item with local rights page" do
    let(:rights_id) { "http://rightsstatements.org/vocab/NoC-US/1.0/" }
    let(:rendered) {  render_inline(RightsIconComponent.new(rights_id: rights_id)) }

    it "links to local page" do
      container = rendered.at_css("div.rights-statement")
      link = container.at_css("a")
      expect(link["href"]).to eq(Rails.application.routes.url_helpers.rights_term_path("NoC-US"))
    end
  end

  describe "alt attr in large render" do
    let(:rights_id) { "http://rightsstatements.org/vocab/InC-EDU/1.0/" }
    let(:rendered) { render_inline(RightsIconComponent.new(rights_id: rights_id, mode: :large)) }
    let(:container) { rendered.at_css("div.rights-statement") }
    let(:image) { container.at_css("img") }

    describe "http://rightsstatements.org/vocab/InC/1.0/" do
      let(:rights_id) { "http://rightsstatements.org/vocab/InC/1.0/" }
      it "has blank alt" do
        expect(container).to be_present
        expect(image["alt"]).to eq ""
      end
    end

    describe "in copyright" do
      RightsTerm.all.
      select { |term| term.category == "in_copyright"}.
      reject {|term| term.id == "http://rightsstatements.org/vocab/InC/1.0/"}.each do |term|
        describe "#{term.id}" do
          let(:rights_id) { term.id }

          it "has correct alt text" do
            expect(container).to be_present
            expect(image["alt"]).to eq "In Copyright"
          end
        end
      end
    end

    describe "no copyright" do
      RightsTerm.all.
      select { |term| term.category == "no_copyright"}.each do |term|
        describe "#{term.id}" do
          let(:rights_id) { term.id }

          it "has correct alt text" do
            expect(container).to be_present
            expect(image["alt"]).to eq "No Copyright"
          end
        end
      end
    end

    describe "unknown status" do
      RightsTerm.all.
      select { |term| term.category == "other"}.each do |term|
        describe "#{term.id}" do
          let(:rights_id) { term.id }

          it "has correct alt text" do
            expect(container).to be_present
            expect(image["alt"]).to eq "Unknown Copyright Status"
          end
        end
      end
    end
  end

  describe "CC license" do
    let(:rights_id) { "https://creativecommons.org/licenses/by-nc-nd/4.0/" }
    let(:rendered) { render_inline(RightsIconComponent.new(rights_id: rights_id)) }

    it "renders" do
      container = rendered.at_css("div.rights-statement")
      expect(container).to be_present

      expect(container["class"].split(" ")).to match(['rights-statement', 'large', 'creative-commons-org'])
      expect(container).to have_selector("img.rights-statement-logo[src*='cc']")

      expect(container.inner_text).to include("This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.")

      images = container.css("img")
      expect(images.find {|i| i['src'].include?("/cc-")}).to be_present
      expect(images.find {|i| i['src'].include?("/by-")}).to be_present
      expect(images.find {|i| i['src'].include?("/nc-")}).to be_present
      expect(images.find {|i| i['src'].include?("/nd-")}).to be_present

      link = container.at_css(".rights-statement-label a")
      expect(link).to be_present
      expect(link["href"]).to eq(rights_id)
      expect(link.inner_html).to include("Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.")
    end

    context "dropdown-item mode" do
      let(:rendered) {  render_inline(RightsIconComponent.new(rights_id: rights_id, mode: :dropdown_item)) }

      it "renders" do
        link = rendered.at_xpath("./a")
        expect(link).to be_present

        expect(link["class"].split(" ")).to match(['rights-statement', 'dropdown-item', 'creative-commons-org'])

        expect(link["href"]).to eq(rights_id)
        expect(link).to have_selector("img.rights-statement-logo[src*='cc']")

        expect(link.inner_html).to include("BY-NC-ND 4.0")
      end
    end
  end

end
