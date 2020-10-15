class Admin::OralHistoryAccessRequest < ApplicationRecord
  encrypts :patron_name, :patron_email, :patron_institution, :intended_use
  belongs_to :work
  validates :patron_name, presence: true
  validates :patron_email, presence: true
  validates :intended_use, presence: true
end