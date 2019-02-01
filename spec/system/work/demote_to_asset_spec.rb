require 'rails_helper'

# We're not gonna test every possible thing here, but a few
RSpec.describe "Convert child work to asset", js: true do
  let(:parent_work) { FactoryBot.create(:work, :with_assets, asset_count: 3) }
  let(:child_work) { FactoryBot.create(:work, :with_assets, parent: parent_work, position: 3) }

  it "demotes to asset" do
    original_position = child_work.position
    asset = child_work.members.first

    expect do
      visit admin_work_path(child_work)

      accept_confirm do
        click_on "Demote to Asset"
      end

      expect(page).to have_current_path(admin_work_path(parent_work))
    end.to change { Work.count }.by(-1).and change { Asset.count }.by(0)

    asset.reload # not raise
    expect(asset.parent).to eq(parent_work)
    expect(asset.position).to eq(original_position)

    expect { child_work.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
