require 'rails_helper'

describe "Featured Topic show page", type: :system, js: false, solr:true do

#describe "Featured Topic show page", solr: true, indexable_callbacks: true do
  it "displays" do
    fake_definition =  {
        test_featured_topic: {
        title: "Instruments & Innovation",
        genre: ["Scientific apparatus and instruments", "Lithographs"],
        subject: ["Artillery", "Machinery", "Chemical apparatus"],
        description: "Fireballs!",
        description_html: "<em>Fireballs!</em>"
      }
    }
    allow(FeaturedTopic).to receive(:definitions).and_return(fake_definition)
    visit featured_topic_path(FeaturedTopic.from_slug(:test_featured_topic).slug)
    expect(page).to have_selector("h1", text: 'Instruments & Innovation')
  end
end
