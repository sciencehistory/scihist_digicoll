# WARNING: changes to these objects don't automatically trigger Work reindex, although may
# require a reindex of associated works. We handle it just in controller update actions.

class IntervieweeBiography < ApplicationRecord
  include AttrJson::Record
  include AttrJson::NestedAttributes

  # If you uncomment these lines, the test database in will not build in CI.
  # scope :find_by_name_substring, ->(query) do
  # end

  has_and_belongs_to_many :oral_history_content

  attr_json :birth,    OralHistoryContent::DateAndPlace.to_type, default: -> { OralHistoryContent::DateAndPlace.new }
  attr_json :death,    OralHistoryContent::DateAndPlace.to_type, default: -> { OralHistoryContent::DateAndPlace.new }

  attr_json :school,  OralHistoryContent::IntervieweeSchool.to_type, array: true, default: -> {[]}
  attr_json :job,     OralHistoryContent::IntervieweeJob.to_type,    array: true, default: -> {[]}
  attr_json :honor,   OralHistoryContent::IntervieweeHonor.to_type,  array: true, default: -> {[]}

  attr_json_accepts_nested_attributes_for :birth, :death, :school, :job, :honor

  validates_presence_of :name
end
