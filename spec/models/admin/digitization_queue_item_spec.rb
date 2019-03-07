require 'rails_helper'

describe Admin::DigitizationQueueItem, type: :model do
  describe "status_changed_at" do
    it "set on initial create" do
      item = FactoryBot.create(:digitization_queue_item)
      expect(item.status_changed_at).to be_present
    end

    it "is changed on status change" do
      item = FactoryBot.create(:digitization_queue_item)
      expect {
        item.update(status: :batch_metadata_complete)
      }.to change {
        item.status_changed_at
      }
    end
  end
end
