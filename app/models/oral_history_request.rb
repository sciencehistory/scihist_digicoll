class OralHistoryRequest < ApplicationRecord
  # longer table name for legacy reasons, cumbersome to change table name
  # without downtime, good enough. eg https://docs.gitlab.com/ee/development/database/rename_database_tables.html
  self.table_name = "oral_history_access_requests"

  belongs_to :patron, optional: true, foreign_key: "oral_history_requester_email_id"
  validates :patron, presence: true
  accepts_nested_attributes_for :patron

  has_encrypted :patron_name, :patron_institution, :intended_use
  belongs_to :work
  validates :patron, presence: true

  # name and institution now live on Patron; these per-request columns are legacy, kept as fallback
  alias_method :legacy_patron_name, :patron_name
  alias_method :legacy_patron_institution, :patron_institution

  def patron_name
    patron&.name.presence || legacy_patron_name
  end

  def patron_institution
    patron&.institution.presence || legacy_patron_institution
  end

  validates :intended_use, presence: true, if: -> {
    work&.oral_history_content&.availability_reviewed_request?
  }

  enum :delivery_status, %w{pending automatic approved rejected dismissed}.map {|v| [v, v]}.to_h, prefix: :delivery_status

  before_save do
    if delivery_status_changed?
      self.delivery_status_changed_at = Time.zone.now
    end
  end

  def oral_history_number
    self.work.oral_history_number
  end

  # delegate to patron
  def patron_email
    patron&.email
  end
end
