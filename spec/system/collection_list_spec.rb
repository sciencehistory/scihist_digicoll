require 'rails_helper'

describe "Collection list page", type: :system do
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
  let!(:exhibition) do
    FactoryBot.create(:collection,
      published: true,
      title: "Our Exhibition",
      department: Collection::DEPARTMENT_EXHIBITION_VALUE
    )
  end

  it "shows published items, doesn't show others." do
    visit collections_path

    expect(page).to be_axe_clean

    expect(page).to have_selector("h1", text: 'Collections')
    expect(page).to have_selector(".collection-title", text: 'A Published')
    expect(page).to have_selector(".collection-title", text: 'B Published')
    expect(page).not_to have_content('Private')
    expect(page).not_to have_content('Our Exhibition')
  end
end
