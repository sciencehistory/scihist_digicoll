require 'rails_helper'

describe WorkResultDisplay do
  let(:parent_work) { create(:work) }
  let(:work) { FactoryBot.create(:work, :with_complete_metadata,
    date_of_work: [Work::DateOfWork.new(start: "2000-01-01", start_qualifier: "circa"), Work::DateOfWork.new(start: "2019-10-10")],
    parent: parent_work,
    source: "Some Source Title",
    genre: ["Advertisements", "Artifacts"],
    additional_title: "An Additional Title") }
  let(:rendered) { Nokogiri::HTML.fragment(described_class.new(work).display) }

  it "displays" do
    work.genre.each do |genre|
      expect(rendered).to have_text(genre)
    end
    expect(rendered).to have_selector("h2 > a", text: work.title)
    expect(rendered).to have_selector("li", text: "An Additional Title")

    expect(rendered).to have_selector("li > a", text: parent_work.title)
    expect(rendered).to have_selector("li > i", text: "Some Source Title")

    expect(rendered).to have_text("Circa 2000-Jan-01")
    expect(rendered).to have_text("2019-Oct-10")
  end
end
