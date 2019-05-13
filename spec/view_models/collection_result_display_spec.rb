require 'rails_helper'

describe CollectionResultDisplay, type: :helper do

  let(:collection) { FactoryBot.create(:collection) }
  let(:rendered) { Nokogiri::HTML.fragment(described_class.new(collection).display) }

  it "displays" do
    expect(rendered).to have_selector("h2 > a", text: collection.title)
  end
end
