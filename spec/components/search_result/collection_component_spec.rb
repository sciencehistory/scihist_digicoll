require 'rails_helper'

describe SearchResult::CollectionComponent, type: :component do
  let(:collection) { FactoryBot.create(:collection, contains: [create(:public_work)]) }
  let(:rendered) { render_inline(described_class.new(collection, child_counter: child_counter)) }

  let(:child_counter) { ChildCountDisplayFetcher.new([collection.friendlier_id]) }

  it "displays" do
    expect(rendered).to have_text("Collection") #genre
    expect(rendered).to have_selector("h2 > a", text: collection.title)
    expect(rendered).to have_content("1 item")
  end
end
