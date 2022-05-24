# WARNING: changes to these objects don't automatically trigger Work reindex, although may
# require a reindex of associated works. We handle it just in controller update actions.

class IntervieweeBiography < ApplicationRecord
  include AttrJson::Record
  include AttrJson::NestedAttributes

  # WORKS:
  #scope :name_is_bill, -> { where(name: "Bill") }

  
  # WORKS
  #scope :name_is_bill_2, ->(query) do
  #  target = "%#{sanitize_sql_like(query.downcase)}%"
  #  where(name: "Bill")
  #end

  # WORKS
  #scope :name_is_bill_3, ->(query) do
  #  target = "%#{sanitize_sql_like(query.downcase)}%"
  #  where(arel_table[:name].matches("%Bill%"))
  #end

  # WORKS
  #scope :name_is_bill_4, ->(query) do
  #  target = "%#{sanitize_sql_like(query.downcase)}%"
  #  where(arel_table[:name].lower.matches("%Bill%"))
  #end

  # WORKS
  #scope :name_is_bill_5, ->(query) do
  #  target = "%#{sanitize_sql_like(query.downcase)}%"
  #  where(arel_table[:name].lower.matches(target))
  #end

  #BREAKS:
  scope :find_by_name_substring, ->(query) do
    target = "%#{sanitize_sql_like(query.downcase)}%"
    where(arel_table[:name].lower.matches(target))
  end


  # BREAKS:
  #scope :find_by_name_substring, ->(query) do
  #  target = "%#{sanitize_sql_like(query.downcase)}%"
  #  where(arel_table[:name].lower.matches(target))
  #end




  has_and_belongs_to_many :oral_history_content

  attr_json :birth,    OralHistoryContent::DateAndPlace.to_type, default: -> { OralHistoryContent::DateAndPlace.new }
  attr_json :death,    OralHistoryContent::DateAndPlace.to_type, default: -> { OralHistoryContent::DateAndPlace.new }

  attr_json :school,  OralHistoryContent::IntervieweeSchool.to_type, array: true, default: -> {[]}
  attr_json :job,     OralHistoryContent::IntervieweeJob.to_type,    array: true, default: -> {[]}
  attr_json :honor,   OralHistoryContent::IntervieweeHonor.to_type,  array: true, default: -> {[]}

  attr_json_accepts_nested_attributes_for :birth, :death, :school, :job, :honor

  validates_presence_of :name
end
