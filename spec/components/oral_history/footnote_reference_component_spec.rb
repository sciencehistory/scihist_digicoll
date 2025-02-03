require 'rails_helper'

describe OralHistory::FootnoteReferenceComponent, type: :component do


  describe "includes escaped title attribute" do
    let(:footnote_text) { "The mathematician's \"daughter\" proved that x > 4." }
    let(:number) { 1 }

    it "includes text in title attribute with proper escaping" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, show_dom_id:true)

      expect(result.at_css("a")["data-bs-content"]).to eq(footnote_text)
      expect(result.at_css("a")['id']).to eq("footnote-reference-1")
    end

    it "only includes an HTML id for the first reference" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, show_dom_id:false)
      expect(result.at_css("a")['id']).to be_nil
    end

  end
end
