class Admin::OralHistoryAccessRequest < ApplicationRecord
  has_encrypted :patron_name, :patron_email, :patron_institution, :intended_use
  belongs_to :work
  validates :patron_name, presence: true
  validates :patron_email, presence: true

  validates :intended_use, presence: true, if: -> {
    work&.oral_history_content&.available_by_request_manual_review?
  }

  enum delivery_status: %w{pending automatic approved rejected}.map {|v| [v, v]}.to_h, _prefix: :delivery_status

  def oral_history_number
    return nil if self.work.external_id.nil?
    oh_id =  self.work.external_id.find {|id| id.attributes["category"] == "interview"}
    return nil if oh_id.nil?
    oh_id.attributes['value']
  end
end
