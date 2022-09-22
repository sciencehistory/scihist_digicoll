require 'rails_helper'

describe AtomEntryComponent, type: :component do
  describe "for work" do
    let(:work) { create(:public_work, :with_complete_metadata) }
    let(:rendered) { render_inline(AtomEntryComponent.new(work)) }

    it "produces atom entry" do
      expect(rendered.at_css("title")&.text).to eq work.title
      expect(rendered.at_css("updated")&.text).to eq work.updated_at.iso8601

      expect(rendered.at_css("link[rel=alternate][type='text/html']")["href"]).to eq work_url(work)
      expect(rendered.at_css("link[rel=alternate][type='application/json']")['href']).to eq work_url(work, format: "json")
      expect(rendered.at_css("link[rel=alternate][type='application/xml']")['href']).to eq work_url(work, format: "xml")

      # I don't know why the namespace is being funny here, not letting us use ordinary
      # nokogiri actual nameespace checking for "media:thumbnanil"
      expect(rendered.at_css("thumbnail").text).to eq WorkOaiDcSerialization.shareable_thumbnail_url(work)

      expect(rendered.at_css("summary[type=html]").text.strip).to eq DescriptionDisplayFormatter.new(work.description).format
    end
  end
end
