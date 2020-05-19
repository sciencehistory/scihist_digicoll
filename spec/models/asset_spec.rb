require 'rails_helper'

describe Asset do
  describe ".all_derivative_count" do
    let!(:assets) { [create(:asset_with_faked_file), create(:asset_with_faked_file)]}

    it "returns good count" do
      expected = assets.collect { |a| a.file_derivatives.count }.sum

      expect(expected).to be > 0
      expect(Asset.all_derivative_count).to eq(expected)
    end
  end
end
