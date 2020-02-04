# This model is based on the parallel Admin::DigitizationQueueItem.rb.

class Admin::RAndRItem < ApplicationRecord
  has_many :digitization_queue_item, dependent: :nullify
  has_many :queue_item_comments, dependent: :destroy

  scope :open_status,   -> { where.not(status: "closed") }
  scope :closed_status, -> { where(    status: "closed") }

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

  COLLECTING_AREAS = Admin::DigitizationQueueItem::COLLECTING_AREAS

  validates :collecting_area, inclusion: { in: COLLECTING_AREAS }

  STATUSES = %w{
    awaiting_dig_on_cart imaging_in_process post_production_completed
    files_sent_to_patron closed
   }

  # Called by /app/views/presenters/_digitization_queue_item_status_form.html.erb
  # Both this class and Admin::DigitizationQueueItem need to implement this,
  # as the presenter is used to show the `status` of
  # instances of both classes.
  def available_statuses
    STATUSES
  end


  CURATORS = %w{ ashley hillary jim patrick molly other }

  validates :status, inclusion: { in: STATUSES }

  validates :title, presence: true

  # Note: We're choosing not to check that the curator is one of
  # the existing list of CURATORS
  # because if one of them is removed
  # from the list... all their ex-R&R-items
  # then fail to validate.
  validates :curator, presence: true

  validates :patron_name, presence: true


  before_validation do
    if self.will_save_change_to_status? || (!self.persisted? && self.status_changed_at.blank?)
      self.status_changed_at = Time.now
    end
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
end
