class InterviewerProfile < ApplicationRecord
  has_and_belongs_to_many :oral_history_content

  # See:
  # https://stackoverflow.com/questions/26775906/escaping-query-for-sql-like-in-rails
  scope :by_name, ->(query) do
    target = "%#{sanitize_sql_like(query.downcase)}%"
    where(arel_table[:name].lower.matches(target))
  end
  validates_presence_of :name, :profile
end
