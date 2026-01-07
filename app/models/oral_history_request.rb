class OralHistoryRequest < ApplicationRecord
  # longer table name for legacy reasons, cumbersome to change table name
  # without downtime, good enough. eg https://docs.gitlab.com/ee/development/database/rename_database_tables.html
  self.table_name = "oral_history_access_requests"

  belongs_to :oral_history_requester, optional: true, foreign_key: "oral_history_requester_email_id"
  validates :oral_history_requester, presence: true
  accepts_nested_attributes_for :oral_history_requester

  has_encrypted :patron_name, :patron_institution, :intended_use
  belongs_to :work
  validates :patron_name, presence: true
  validates :oral_history_requester, presence: true

  validates :intended_use, presence: true, if: -> {
    work&.oral_history_content&.available_by_request_manual_review?
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

  # delegate to oral_history_requester, or while we're migrating default to
  # local attributes
  def requester_email
    oral_history_requester&.email
  end
end
