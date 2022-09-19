require 'rails_helper'

describe RelatedLinkComponent, type: :component do
  let(:related_link) { RelatedLink.new(category: "distillations_article", label: "Some Article", url: "http://example.sciencehistory.com/distillations/article")}

  it "renders" do
    render_inline(RelatedLinkComponent.new(related_link: related_link))

    expect(page).to have_text("Distillations article")

    link = page.find("a[href='#{related_link.url}']", text: related_link.label)
    expect(link).to be_present
    expect(link["target"]).to be_nil
  end

  describe "with no label" do
    let(:related_link) { RelatedLink.new(category: "distillations_article", url: "http://example.sciencehistory.com/distillations/article")}

    it "renders URL as label" do
      render_inline(RelatedLinkComponent.new(related_link: related_link))
          expect(page).to have_css("a[href='#{related_link.url}']", text: related_link.url)
    end
  end

  describe "for external link type" do
    let(:related_link) { RelatedLink.new(category: "other_external", label: "Some Article", url: "http://example.com/something")}

    it "renders header as 'Link'" do
      render_inline(RelatedLinkComponent.new(related_link: related_link))

      expect(page).to have_text("Link")
      expect(page).not_to have_text("Other external")
    end

    it "renders domain next to link" do
      render_inline(RelatedLinkComponent.new(related_link: related_link))

      expect(page).to have_content(/#{related_link.label}\s+\(example.com\)/)
    end

    it "renders with target _blank" do
      render_inline(RelatedLinkComponent.new(related_link: related_link))

      link = page.find("a")
      expect(link["target"]).to eq("_blank")
    end
  end
end
