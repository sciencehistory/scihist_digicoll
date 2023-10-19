# Finds the next and previous members in a work.
# In cases where positions are noncontiguous or nil,
# you can still navigate through the members sequentially.
# Could be more efficient, but also not horribly inefficient.
class MemberPreviousAndNextGetter
  attr_reader :asset

  # @param member [Kithe::Model]
  def initialize(member)
    @member = member
  end

  def previous_and_next
    {
       previous: previous_model,
       next:     next_model
    }
  end

  def previous_model
    @previous_model ||= (Kithe::Model.find(query["previous_id"]) if query["previous_id"].present?)
  end

  def next_model
    @next_model     ||= (Kithe::Model.find(query["next_id"])     if query["next_id"].present?)
  end

  def query
    @query ||= ActiveRecord::Base.connection.execute("""
    SELECT * from ( SELECT id,
      LAG(id,  1) over (order by position, id) as previous_id,
      LEAD(id, 1) over (order by position, id) as next_id
      FROM (
        SELECT id, position FROM kithe_models
        WHERE parent_id = '#{@member.parent.id}'
      ) as members
    ) as ordered
    where id = '#{@member.id}'
    """)[0]
  end
end

