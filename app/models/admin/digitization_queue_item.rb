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


  # Some collecting-area-specific required fields. Need to put them in a hash to allow reflection,
  # so that we can make sure to display 'required' label on entry form as appropriate.
  REQUIRED_PER_COLLECTING_AREA = {
    archives: [:accession_number],
    photographs: [:accession_number],
    rare_books: [:bib_number, :location],
    modern_library: [:bib_number, :location],
    museum_objects: [:accession_number, :museum_object_id],
    museum_fine_art: [:accession_number, :museum_object_id],
  }

  with_options if: -> i { i.collecting_area == "archives" } do |item|
    item.validates *REQUIRED_PER_COLLECTING_AREA[:archives], presence: true
  end

  with_options if: -> i { i.collecting_area == "photographs"} do |item|
    item.validates *REQUIRED_PER_COLLECTING_AREA[:photographs], presence: true
  end

  with_options if: -> i { i.collecting_area == "rare_books"} do |item|
    item.validates *REQUIRED_PER_COLLECTING_AREA[:rare_books], presence: true
  end

  with_options if: -> i { i.collecting_area == "modern_library"} do |item|
    item.validates *REQUIRED_PER_COLLECTING_AREA[:modern_library], presence: true
  end

  with_options if: -> i { i.collecting_area == "museum_objects"} do |item|
    item.validates *REQUIRED_PER_COLLECTING_AREA[:museum_objects], presence: true
  end

  with_options if: -> i { i.collecting_area == "museum_fine_art"} do |item|
    item.validates *REQUIRED_PER_COLLECTING_AREA[:museum_fine_art], presence: true
  end


  before_validation do
    if self.will_save_change_to_status? || (!self.persisted? && self.status_changed_at.blank?)
      self.status_changed_at = Time.now
    end
  end

  # convenience for front-end to display "required" badge for fields required
  # for only certain collecting_areas, enforced by validation above
  def field_is_required_for_collecting_area?(field_name)
    return false if collecting_area.blank?

    (REQUIRED_PER_COLLECTING_AREA[collecting_area.to_sym] || []).include?(field_name.to_sym)
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
