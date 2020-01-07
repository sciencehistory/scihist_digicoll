require 'rails_helper'
describe Admin::RAndRItem, type: :model do
  describe "status_changed_at" do
    it "set on initial create" do
      item = FactoryBot.create(:r_and_r_item)
      expect(item.status_changed_at).to be_present
    end

    it "is changed on status change" do
      item = FactoryBot.create(:r_and_r_item)
      pp item
      expect {
        item.update(status: :batch_metadata_complete)
      }.to change {
        item.status_changed_at
      }
    end
  end
end