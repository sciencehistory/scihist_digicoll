class Admin::InterviewerProfile < ApplicationRecord
  validates_presence_of :name, :profile
end
