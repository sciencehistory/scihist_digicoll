require 'rails_helper'

describe "Featured Topic show page", type: :system, js: false, solr:true, indexable_callbacks: true do
  let!(:three_sample_works ) do
    [
      create(:public_work, title: "artillery", subject: ["Artillery"]),
      create(:public_work, title: "lithographs", genre: ["Lithographs"]),
      create(:private_work, title: "machinery", subject: ["Machinery"])
    ]
  end

  it "smoke tests" do
    fake_definition =  {
        instruments_and_innovation: {
        title: "Instruments & Innovation",
        genre: ["Scientific apparatus and instruments", "Lithographs"],
        subject: ["Artillery", "Machinery", "Chemical apparatus"],
        description: "Fireballs!",
        description_html: "<em>Fireballs!</em>"
      }
    }
    allow(FeaturedTopic).to receive(:definitions).and_return(fake_definition)
    visit featured_topic_path('instruments-and-innovation')
    expect(page).to have_title "Instruments & Innovation"
    expect(page).to have_selector("h1", text: 'Instruments & Innovation')
    expect(page).to have_selector("p", text: 'Fireballs')
    expect(page).to have_content("artillery")
    expect(page).to have_content("lithographs")
    expect(page).not_to have_content("machinery")
  end
end
