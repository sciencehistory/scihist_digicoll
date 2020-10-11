class Admin::OralHistoryAccessRequest < ApplicationRecord
  encrypts :patron_name, :patron_email, :patron_institution, :intended_use
  belongs_to :work
  validate :work_exists
  def work_exists
    Work.exists?(self.work_id);
  end
end