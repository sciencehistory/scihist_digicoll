require 'rails_helper'

describe "Collection list page", type: :system, js: false do
  let!(:private_collection) do
    FactoryBot.create(:collection,
      published: false,
      title: "Private"
    )
  end
  let!(:published_collection_1) do
    FactoryBot.create(:collection,
      published: true,
      title: "A Published"
    )
  end
  let!(:published_collection_2) do
    FactoryBot.create(:collection,
      published: true,
      title: "B Published"
    )
  end

  it "shows published items, doesn't show others." do
    visit collections_path
    expect(page).to have_selector("h1", text: 'All Collections')
    expect(page).to have_selector(".collection-title", text: 'A Published')
    expect(page).to have_selector(".collection-title", text: 'B Published')
    expect(page).not_to have_content('Private')
  end
end
