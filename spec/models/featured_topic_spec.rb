require 'rails_helper'

RSpec.describe FeaturedTopic, no_clean: true do
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

  describe "solr_fq" do
    FeaturedTopic.keys.each do |key|
      it "translates #{key}" do
        result = FeaturedTopic.new(key).solr_fq
        expect(result).to match EXPECTED_SHAPE
      end
    end
  end
end
