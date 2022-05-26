class ConsolidateDigQueueCollectingAreas < ActiveRecord::Migration[6.1]
  # change from legacy collecting areas to new ones they are meant to be merged into.
  def change
    Admin::DigitizationQueueItem.where(collecting_area: "photographs").update_all(collecting_area: "archives")
    Admin::DigitizationQueueItem.where(collecting_area: "museum_objects").update_all(collecting_area: "museum")
    Admin::DigitizationQueueItem.where(collecting_area: "museum_fine_art").update_all(collecting_area: "museum")
  end
end
