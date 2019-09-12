require 'rails_helper'
require 'scihist_digicoll/assets_needing_fixity_checks'

describe ScihistDigicoll::AssetsNeedingFixityChecks do
  let(:cycle_length) { 7 }
  let(:checker) { ScihistDigicoll::AssetsNeedingFixityChecks.new(cycle_length) }

  describe "sql" do
    let(:cycle_length) { 3 }
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
        WHERE \"kithe_models\".\"type\" IN ('Asset')
        GROUP BY \"kithe_models\".\"id\"
        ORDER BY max(fixity_checks.created_at) nulls first
        LIMIT 1
      """.gsub(/\s+/, ' ').strip

      actual = checker.send(:selected_assets_scope).to_sql.gsub(/\s+/, ' ').strip

      expect(actual).to eq(expected), "\nexpected: #{expected}\n     got: #{actual}\n"
    end
  end
end
