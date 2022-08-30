require 'rails_helper'

describe RelatedLinkComponent, type: :component do
  let(:related_link) { RelatedLink.new(category: "distillations_article", label: "Some Article", url: "http://example.sciencehistory.com/distillations/article")}

  it "renders" do
    render_inline(RelatedLinkComponent.new(related_link: related_link))

    expect(page).to have_text("Distillations article")
    expect(page).to have_css("a[href='#{related_link.url}']", text: related_link.label)
  end

  describe "with no label" do
    let(:related_link) { RelatedLink.new(category: "distillations_article", url: "http://example.sciencehistory.com/distillations/article")}

    it "renders URL as label" do
      render_inline(RelatedLinkComponent.new(related_link: related_link))
          expect(page).to have_css("a[href='#{related_link.url}']", text: related_link.url)
    end
  end
end
