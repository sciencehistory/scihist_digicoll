class OralHistoryRequest < ApplicationRecord
  # longer table name for legacy reasons, cumbersome to change table name
  # without downtime, good enough. eg https://docs.gitlab.com/ee/development/database/rename_database_tables.html
  self.table_name = "oral_history_access_requests"

  # foreign key has legacy name that doesn't quite match, sorry.
  # optional until we migrate all emails from existing requests
  # At that point we should make the oral_history_requester_email_id in DB non-null too!
  belongs_to :oral_history_requester, optional: true, foreign_key: "oral_history_requester_email_id"
  validates :oral_history_requester, presence: true, if: -> { patron_email.blank? }
  validates :patron_email, absence: true, if: -> { oral_history_requester.present? }
  accepts_nested_attributes_for :oral_history_requester

  has_encrypted :patron_name, :patron_email, :patron_institution, :intended_use
  belongs_to :work
  validates :patron_name, presence: true

  validates :intended_use, presence: true, if: -> {
    work&.oral_history_content&.available_by_request_manual_review?
  }

  enum delivery_status: %w{pending automatic approved rejected}.map {|v| [v, v]}.to_h, _prefix: :delivery_status

  before_save do
    if delivery_status_changed?
      self.delivery_status_changed_at = Time.zone.now
    end
  end

  def oral_history_number
    return nil if self.work.external_id.nil?
    oh_id =  self.work.external_id.find {|id| id.attributes["category"] == "interview"}
    return nil if oh_id.nil?
    oh_id.attributes['value']
  end


  # delegate to oral_history_requester, or while we're migrating default to
  # local attributes
  def requester_email
    oral_history_requester&.email || patron_email
  end


end
