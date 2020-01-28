class Admin::RAndRItem < ApplicationRecord
  belongs_to :digitization_queue_item, optional: true

  before_destroy :remove_reference_from_dq_table

  scope :open_status,   -> { where.not(status: "closed_r_and_r_request") }
  scope :closed_status, -> { where(    status: "closed_r_and_r_request") }

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
    files_sent_to_patron closed_r_and_r_request
   }

  CURATORS = %w{ ashley hillary jim patrick molly other }

  validates :status, inclusion: { in: STATUSES }

  validates :title, presence: true

  validates :curator, inclusion: { in: CURATORS }, presence: true
  validates :patron_name, presence: true


  before_validation do
    if self.will_save_change_to_status? || (!self.persisted? && self.status_changed_at.blank?)
      self.status_changed_at = Time.now
    end
  end

  # Is this ready to make a DigitizationQueueItem out of?
  def ready_to_move_to_digitization_queue
    return false if self.digitization_queue_item
    return false unless self.is_destined_for_ingest
    return false if self.copyright_research_still_needed
    return false unless self.ready_to_move_to_digitization_queue_based_on_status
    return true
  end

  def ready_to_move_to_digitization_queue_based_on_status
    possible_statuses = %w{post_production_completed files_sent_to_patron closed_r_and_r_request}
    possible_statuses.include?(self.status)
  end

  # Fill out a DigitizationQueueItem with metadata in here. Does not save.
  #
  # Note:
  # We do *not* want to bring over the :instructions field, because those
  # instructions pertain strictly to the digitization process and are
  # irrelevant once the item is digitized (which it has to be by the time
  # it moves out of the R&R queue).
  def fill_out_digitization_queue_item(digitization_queue_item)
    stuff_to_copy_over = [
      :bib_number, :accession_number, :museum_object_id,
      :box, :folder, :dimensions, :location,
      :collecting_area, :materials,
      :additional_notes, :copyright_status,
    ]

    stuff_to_copy_over.each do | key |
      value = self.send(key)
      if value.present?
        digitization_queue_item.send "#{key}=", value
      end
    end
    digitization_queue_item.title = self.title
    # self.scope refers to the R&R request scope.
    digitization_queue_item.scope = self.additional_pages_to_ingest

  end

  def digitization_queue_item
    Admin::DigitizationQueueItem.find_by(r_and_r_item_id:self.id)
  end

  def remove_reference_from_dq_table
    my_dq_item =  self.digitization_queue_item
    return unless my_dq_item
    my_dq_item.r_and_r_item_id = nil
    my_dq_item.save!
  end

end
