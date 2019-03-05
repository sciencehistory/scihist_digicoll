class Admin::DigitizationQueueItem < ApplicationRecord
  has_many :queue_item_comments, dependent: :destroy

  has_many :works

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

  before_validation do
    if self.will_save_change_to_status? || (!self.persisted? && self.status_changed_at.blank?)
      self.status_changed_at = Time.now
    end
  end
end
