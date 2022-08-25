require 'rails_helper'

describe "Featured Topic show page", type: :system, js: false, solr:true, indexable_callbacks: true do
  let!(:three_sample_works ) do
    [
      create(:public_work, title: "artillery", subject: ["Artillery"]),
      create(:public_work, title: "lithographs", genre: ["Lithographs"]),
      create(:private_work, title: "machinery", subject: ["Machinery"])
    ]
  end

  let(:oral_history_collection_id) { ScihistDigicoll::Env.lookup!(:oral_history_collection_id) }

  let!(:oh_collection) do
    create(:collection, friendlier_id: oral_history_collection_id, title: 'Oral History Collection')
  end

  let(:fake_definition) do
    {
      :instruments_and_innovation => {
        title: "Instruments & Innovation",
        genre: ["Scientific apparatus and instruments", "Lithographs"],
        subject: ["Artillery", "Machinery", "Chemical apparatus"],
        description: "Fireballs!",
        description_html: "<em>Fireballs!</em>"
      },

      :oral_histories => {
        title: "Oral Histories",
        path: "/collections/#{oral_history_collection_id}"
      }
    }
  end

  before do
    allow(FeaturedTopic).to receive(:definitions).and_return(fake_definition)
  end

  it "smoke tests" do
    visit featured_topic_path(:instruments_and_innovation.to_s.dasherize)
    expect(page).to have_title "Instruments & Innovation"
    expect(page).to have_selector("h1", text: 'Instruments & Innovation')
    expect(page).to have_text("2 items")
    expect(page).to have_selector("p", text: 'Fireballs')
    expect(page).to have_content("artillery")
    expect(page).to have_content("lithographs")
    expect(page).not_to have_content("machinery")
  end

  it "searches, and keeps total count accurate" do
    visit featured_topic_path(:instruments_and_innovation.to_s.dasherize, q: "artillery")

    expect(page).to have_text("1 entry found")

    expect(page).to have_content("artillery")
    expect(page).not_to have_content("lithographs")
  end

  it "can be set to an arbitrary URL by setting the path variable" do
    visit FeaturedTopic.from_slug(:oral_histories).path
    expect(page).to have_content(oh_collection.title)
  end

end
