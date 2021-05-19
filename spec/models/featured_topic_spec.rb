require 'rails_helper'
# Pretty ridiculous to check output with this hairy regexp for
# general shape of a good expected query. Def not perfect, but works
# for now.
EXPECTED_SHAPE = /\A
      ( \w+\:
        \(
          ( \"[^"]+\"
            (\sOR\s)?
          )+
        \)
        (\sOR\s)?
      )
/x

# This commented out double-quote is a
# workaround for a bug with
# bad regex parsing in certain text editors: "

describe FeaturedTopic, no_clean: true do

  # Note: Featured topics that serve as
  # links (currently only the "oral history" featured topic) are trivial,
  # and their functioning is already covered in /spec/system/featured_topic_spec.rb,
  # so we ignore them here.

  let(:regular_featured_topics) do
    FeaturedTopic.all.select { |fp| fp.path.include?('focus') }
  end

  describe "smoke tests" do
    it "correctly loads all the topics" do
      expect(FeaturedTopic.all.count).to eq FeaturedTopic.definitions.count
    end
    it "constructs solar queries properly" do
      regular_featured_topics.each do |featured_topic|
        expect(featured_topic.solr_fq).to match EXPECTED_SHAPE
      end
    end
    it "constructs path properly" do
      regular_featured_topics.each do |featured_topic|
        expect(featured_topic.path).to match /^focus\/#{featured_topic.slug}/
      end
    end
  end

  describe "basic operation" do
    it "functions as expected" do
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
      expect(FeaturedTopic.from_slug(:test_featured_topic)).to be_a FeaturedTopic
      fake_topic = FeaturedTopic.all.first
      expect(fake_topic.path).to eq "focus/test-featured-topic"
      expect(fake_topic.slug).to eq "test-featured-topic"
      expect(fake_topic.title).to eq "Instruments & Innovation"
      expect(fake_topic.description).to eq "<em>Fireballs!</em>"
      expect(fake_topic.description.html_safe?).to be true
      expect(fake_topic.solr_fq.split("OR")).to eq [
        'subject_facet:("Artillery" ',' "Machinery" ', ' "Chemical apparatus") ',
        ' genre_facet:("Scientific apparatus and instruments" ', ' "Lithographs")'
      ]
      expect(fake_topic.thumb_asset_path).to eq "featured_topics/test_featured_topic_2x.jpg"
    end
  end
end
