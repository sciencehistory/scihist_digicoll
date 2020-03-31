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

    it "can fill out new DigitizationQueueItem with its own metadata" do
      item = FactoryBot.create(:r_and_r_item)
      new_item = Admin::DigitizationQueueItem.new()
      item.fill_out_digitization_queue_item(new_item)
      # Note: we are not moving :instructions over,
      # on purpose. See the method fill_out_digitization_queue_item
      # itself for an explanation.
      stuff_to_copy_over = [
        :bib_number, :accession_number, :museum_object_id,
        :box, :folder, :dimensions, :location,
        :collecting_area, :materials, :title,
        :additional_notes, :copyright_status,
      ]
      stuff_to_copy_over.each do | key |
        expect(new_item.send(key)).to eq item.send(key)
      end
      # self.scope refers to the R&R request scope.
      expect(new_item.scope).to eq item.additional_pages_to_ingest
      # self.scope refers to the R&R request scope.
      expect(new_item.status).to eq 'post_production_completed'
    end
  end
end