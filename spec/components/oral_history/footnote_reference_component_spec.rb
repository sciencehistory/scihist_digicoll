require 'rails_helper'

describe OralHistory::FootnoteReferenceComponent, type: :component do


  describe "includes escaped title attribute" do
    let(:footnote_text) { "The mathematician's \"daughter\" proved that x > 4." }
    let(:number) { 1 }

    it "includes text in title attribute with proper escaping" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number)

      expect(result.at_css("a")["title"]).to eq(footnote_text)
    end
  end
end
