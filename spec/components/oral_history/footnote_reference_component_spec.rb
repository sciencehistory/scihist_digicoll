require 'rails_helper'

describe OralHistory::FootnoteReferenceComponent, type: :component do


  describe "includes escaped title attribute" do
    let(:footnote_text) { "The mathematician's \"daughter\" proved that x > 4." }
    let(:number) { 1 }

    it "includes text in attribute" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, show_dom_id:true)

      expect(result.at_css("a")["data-bs-content"]).to eq(footnote_text)
      expect(result.at_css("a")['id']).to eq("footnote-reference-1")
    end

    it "does not include html-safety by default" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, show_dom_id:true)

      expect(result.at_css("a")['data-bs-html']).to be nil
    end

    it "has footnote reference in link text" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, show_dom_id:true)
      expect(result.at_css("a").text.strip).to eq "[#{number}]"
    end

    it "does not include HTML id if suppressed" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, show_dom_id:false)
      expect(result.at_css("a")['id']).to be_nil
    end

    it "includes prefatory link_content when asked" do
      result = render_inline described_class.new(footnote_text: footnote_text, number: number, link_content: "extra text")
      expect(result.at_css("a").text.strip).to eq "extra text [#{number}]"
    end

    it "tells bootstrap html if footnote_text is html_safe" do
      result = render_inline described_class.new(footnote_text: "This is <b>html safe</b>".html_safe, number: number)
      expect(result.at_css("a")["data-bs-content"]).to eq("This is <b>html safe</b>")
      expect(result.at_css("a")['data-bs-html']).to eq "true"
    end
  end
end
