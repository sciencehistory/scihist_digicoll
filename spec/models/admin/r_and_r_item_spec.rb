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
      expect(item.ready_to_move_to_digitization_queue?).to be false
      item.status = 'files_sent_to_patron'
      expect(item.ready_to_move_to_digitization_queue?).to be true
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
      item.fill_out_digitization_queue_item(new_item)
      stuff_to_copy_over = [
        :bib_number, :accession_number, :museum_object_id,
        :box, :folder, :dimensions, :location,
        :collecting_area, :materials, :title,
        :instructions, :additional_notes, :copyright_status,
      ]
      stuff_to_copy_over.each do | key |
        expect(new_item.send(key)).to eq item.send(key)
      end
      # self.scope refers to the R&R request scope.
      expect(new_item.scope).to eq item.additional_pages_to_ingest
    end
  end
end