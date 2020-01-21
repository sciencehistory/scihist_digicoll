require 'rails_helper'

describe CollectionResultDisplay do
  let(:collection) { FactoryBot.create(:collection, contains: [create(:public_work)]) }
  let(:rendered) { Nokogiri::HTML.fragment(described_class.new(collection, child_counter: child_counter).display) }

  let(:child_counter) { ChildCountDisplayFetcher.new([collection.friendlier_id]) }

  it "displays" do
    expect(rendered).to have_text("Collection") #genre
    expect(rendered).to have_selector("h2 > a", text: collection.title)
    expect(rendered).to have_content("1 item")
  end
end
