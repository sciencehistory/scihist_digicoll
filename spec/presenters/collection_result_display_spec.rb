require 'rails_helper'

describe CollectionResultDisplay do
  let(:collection) { FactoryBot.create(:collection, contains: [create(:work)]) }
  let(:rendered) { Nokogiri::HTML.fragment(described_class.new(collection).display) }

  before do
    # normally provided by CatalogController, the WorkResultDisplay does
    # expect controller to provide this, we mock it here.
    without_partial_double_verification do
      allow(helpers).to receive(:child_counter).and_return(ChildCountDisplayFetcher.new([collection.friendlier_id]))
    end
  end


  it "displays" do
    expect(rendered).to have_text("Collection") #genre
    expect(rendered).to have_selector("h2 > a", text: collection.title)
    expect(rendered).to have_content("1 item")
  end
end
