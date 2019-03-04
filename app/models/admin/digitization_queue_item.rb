class Admin::DigitizationQueueItem < ApplicationRecord
  # collecting areas could have been normalized as a separate table, but
  # not really needed, we'll just leave it as a controlled string.
  COLLECTING_AREAS = %w{archives photographs rare_books modern_library museum_objects museum_fine_art}
  validates :collecting_area, inclusion: { in: COLLECTING_AREAS }

  STATUSES = %w{
    awaiting_dig_on_cart imaging_in_process imaging_completed post_production_completed
    batch_metadata_completed individual_metadata_completed closed re_pull_object
   }
  validates :status, inclusion: { in: STATUSES }

  validates :title, presence: true
end
