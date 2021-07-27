require 'rails_helper'

# in a separate spec file because we likely want to extract to kithe
describe "Work#all_descendent_members" do
  let!(:work) { FactoryBot.create(:work, title: "top") }
  let!(:intermediate_work) { FactoryBot.create(:work, title: "intermediate", parent_id: work.id) }
  let!(:asset) { FactoryBot.create(:asset, parent_id: intermediate_work.id) }

  let!(:unrelated_work){ FactoryBot.create(:work, title: "unrelated") }

  it "finds all" do
    expect(work.all_descendent_members.to_a.collect(&:id)).to match([intermediate_work.id, asset.id])
  end
end
