class Admin::DigitizationQueueItem < ApplicationRecord
  has_many :queue_item_comments, dependent: :destroy

  has_many :works

  scope :open_status, -> { where.not(status: "closed") }

  # for now just validate bib numbers to not have the extra digit.
  # We could try to 'automatically' fix them if this is still too
  # confusing for curators
  class StartsWithBValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      value = record.send(attribute)
      unless (value.blank? || value.starts_with?("b"))
        record.errors[attribute] << (options[:message] || "must start with b")
      end
    end
  end
  validates :bib_number, length: { is: 8 }, allow_blank: true, starts_with_b: true

  # collecting areas could have been normalized as a separate table, but
  # not really needed, we'll just leave it as a controlled string.
  COLLECTING_AREAS = %w{archives photographs rare_books modern_library museum_objects museum_fine_art}
  validates :collecting_area, inclusion: { in: COLLECTING_AREAS }

  STATUSES = %w{
    awaiting_dig_on_cart imaging_in_process post_production_completed
    batch_metadata_completed individual_metadata_completed closed hold re_pull_object
   }
  validates :status, inclusion: { in: STATUSES }

  # Called by /app/views/presenters/_digitization_queue_item_status_form.html.erb
  # Both this class and Admin::RAndRItem need to implement this,
  # as the presenter is used to show the `status` of
  # instances of both classes.
  def available_statuses
    STATUSES
  end

  validates :title, presence: true

  before_validation do
    if self.will_save_change_to_status? || (!self.persisted? && self.status_changed_at.blank?)
      self.status_changed_at = Time.now
    end
  end


  # Fill out a work with metadata in here, does not save
  def fill_out_work(work)
    work.title            = self.title

    if self.bib_number.present?
      work.build_external_id(category: "bib", value: self.bib_number)
    end
    if self.accession_number.present?
      work.build_external_id(category: "accn", value: self.accession_number)
    end
    if self.museum_object_id.present?
      work.build_external_id(category: "object", value: self.museum_object_id)
    end
    if self.box.present? || self.folder.present?
      work.physical_container = {box: self.box.presence, folder: self.folder.presence}
    end
    if self.dimensions.present?
      work.extent =  self.dimensions
    end
    if self.materials.present?
      work.medium = self.materials
    end
  end
end
