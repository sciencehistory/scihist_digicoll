# Finds the next and previous members in a work.
# In cases where positions are noncontiguous, non-unique, or nil,
# you can still navigate through the members sequentially.
class MemberPreviousAndNextGetter
  # @param member [Kithe::Model]
  def initialize(member)
    @member = member
  end

  def previous_model
    @previous_model ||= (Kithe::Model.find(query["previous_id"]) if query["previous_id"].present?)
  end

  def next_model
    @next_model     ||= (Kithe::Model.find(query["next_id"])     if query["next_id"].present?)
  end

  # Takes 1 to 3 milliseconds to run.
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

