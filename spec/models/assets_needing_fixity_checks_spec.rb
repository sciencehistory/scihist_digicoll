require 'rails_helper'
require 'scihist_digicoll/assets_needing_fixity_checks'

# This shouldn't be necessary to make sure Rails knows about our STI hieararchy and works
# reliably, but somehow it is. :(
CollectionThumbAsset.connection

describe ScihistDigicoll::AssetsNeedingFixityChecks do
  let(:cycle_length) { 3 }
  let(:checker) { ScihistDigicoll::AssetsNeedingFixityChecks.new(cycle_length) }

  describe "#selected_assets_scope" do
    before do
      3.times do
        create(:asset)
      end
    end

    it "is constructed sensibly" do
      expected = """
        SELECT kithe_models.id
        FROM \"kithe_models\"
        LEFT OUTER JOIN \"fixity_checks\"
        ON \"fixity_checks\".\"asset_id\" = \"kithe_models\".\"id\"
        WHERE \"kithe_models\".\"type\" IN ('Asset', 'CollectionThumbAsset')
        GROUP BY \"kithe_models\".\"id\"
        ORDER BY max(fixity_checks.created_at) nulls first
        LIMIT 1
      """.gsub(/\s+/, ' ').strip

      actual = checker.send(:selected_assets_scope).to_sql.gsub(/\s+/, ' ').strip

      expect(actual).to eq(expected), "\nexpected: #{expected}\n     got: #{actual}\n"
    end
  end

  describe "#assets_to_check" do
    let!(:blank_one) { create(:asset) }
    let!(:old_one) { create(:asset, fixity_checks: [FixityCheck.new(created_at: 1.year.ago)]) }

    before do
      # some newer ones
      4.times do |i|
        create(:asset, fixity_checks: [FixityCheck.new(created_at: i.days.ago)])
      end
    end

    it "are correct" do
      expect(checker.assets_to_check.collect(&:id)).to contain_exactly(blank_one.id, old_one.id)
    end
  end
end
