class InterviewerProfile < ApplicationRecord
  has_and_belongs_to_many :oral_history_content

  validates_presence_of :name, :profile
end
