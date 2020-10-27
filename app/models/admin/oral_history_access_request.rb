class Admin::OralHistoryAccessRequest < ApplicationRecord
  encrypts :patron_name, :patron_email, :patron_institution, :intended_use
  belongs_to :work
  validates :patron_name, presence: true
  validates :patron_email, presence: true
  validates :intended_use, presence: true

  def oral_history_number
    return nil if self.work.external_id.nil?
    oh_id =  self.work.external_id.find {|id| id.attributes["category"] == "interview"}
    return nil if oh_id.nil?
    oh_id.attributes['value']
  end
end