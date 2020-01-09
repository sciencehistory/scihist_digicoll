require 'rails_helper'
describe Admin::RAndRItem, type: :model do
  describe "status_changed_at" do
    it "set on initial create" do
      item = FactoryBot.create(:r_and_r_item)
      expect(item.status_changed_at).to be_present
    end

    it "is changed on status change" do
      item = FactoryBot.create(:r_and_r_item)
      expect {
        item.update(status: :batch_metadata_complete)
      }.to change {
        item.status_changed_at
      }
    end

    it "checks whether item has the right status" do
      item = FactoryBot.create(:r_and_r_item,
          is_destined_for_ingest: true,
          copyright_research_still_needed: false,
          status: 'awaiting_dig_on_cart')
      expect(item.ready_to_move_to_digitization_queue).to be false
      item.status = 'files_sent_to_patron'
      expect(item.ready_to_move_to_digitization_queue).to be true
    end

    it "checks whether item is destined for ingest" do
      item = FactoryBot.create(:r_and_r_item,
          is_destined_for_ingest: false,
          copyright_research_still_needed: false,
          status: 'files_sent_to_patron')
      expect(item.ready_to_move_to_digitization_queue).to be false
      item.is_destined_for_ingest = true
      expect(item.ready_to_move_to_digitization_queue).to be true
    end

    it "checks whether copyright_research_still_needed" do
      item = FactoryBot.create(:r_and_r_item,
          is_destined_for_ingest: true,
          copyright_research_still_needed: true,
          status: 'files_sent_to_patron')
      expect(item.ready_to_move_to_digitization_queue).to be false
      item.copyright_research_still_needed = false
      expect(item.ready_to_move_to_digitization_queue).to be true
    end


    it "can fill out new DigitizationQueueItem with its own metadata" do
      item = FactoryBot.create(:r_and_r_item)
      new_item = Admin::DigitizationQueueItem.new()
      item.fill_out_work(new_item)
      expect(new_item.title).to eq "Some Item"
      expect(new_item.collecting_area).to eq "archives"
      expect(new_item.bib_number).to eq "b1234567"
      expect(new_item.copyright_status).to eq "Unclear"
    end
  end
end