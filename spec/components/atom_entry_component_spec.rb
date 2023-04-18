require 'rails_helper'

describe AtomEntryComponent, type: :component do
  describe "for work" do
    let(:work) { create(:public_work, :with_complete_metadata) }
    let(:rendered) {Nokogiri.XML(render_inline(AtomEntryComponent.new(work)).to_s)}

    it "produces atom entry" do
      expect(rendered.at_css("title")&.text).to eq work.title
      expect(rendered.at_css("updated")&.text).to eq work.updated_at.iso8601
      expect(rendered.at_css("link[rel=alternate][type='text/html']")["href"]).to eq work_url(work)
      expect(rendered.at_css("link[rel=alternate][type='application/json']")['href']).to eq work_url(work, format: "json")
      expect(rendered.at_css("link[rel=alternate][type='application/xml']")['href']).to eq work_url(work, format: "xml")
      # This is the <media:thumbnail> tag. (Colons in css selectors are escaped as a pipe character.)
      # https://nokogiri.org/tutorials/searching_a_xml_html_document.html#namespaces
      expect(rendered.at_css("media|thumbnail").text).to eq WorkOaiDcSerialization.shareable_thumbnail_url(work)
      expect(rendered.at_css("summary[type=html]").text.strip).to eq DescriptionDisplayFormatter.new(work.description).format
    end
  end

  describe "for collection" do
    let(:collection) { create(:collection, :with_representative, published: true) }
    let(:rendered) { Nokogiri.XML(render_inline(AtomEntryComponent.new(collection)).to_s) }

    it "produces atom entry" do
      expect(rendered.at_css("title")&.text).to eq collection.title
      expect(rendered.at_css("updated")&.text).to eq collection.updated_at.iso8601
      expect(rendered.at_css("link[rel=alternate][type='text/html']")["href"]).to eq collection_url(collection)
      # we don't support collection metadata APIs at present
      expect(rendered.at_css("link[rel=alternate][type='application/json']")).to be_nil
      expect(rendered.at_css("link[rel=alternate][type='application/xml']")).to be_nil
      # see comment above
      expect(rendered.at_css("media|thumbnail").text).to eq WorkOaiDcSerialization.shareable_thumbnail_url(collection)
      expect(rendered.at_css("summary[type=html]").text.strip).to eq DescriptionDisplayFormatter.new(collection.description).format
    end
  end
end
