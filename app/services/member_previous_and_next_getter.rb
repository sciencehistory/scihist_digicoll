# Finds the next and previous members in a work.
# In cases where positions are noncontiguous, non-unique, or nil,
# you can still navigate through the members sequentially.
class MemberPreviousAndNextGetter
  # @param member [Kithe::Model]
  def initialize(member)
    @member = member
  end

  def previous_friendlier_id
    @previous_friendlier_id ||= query&.dig("previous_friendlier_id")
  end

  def next_friendlier_id
    @next_friendlier_id     ||=query&.dig("next_friendlier_id")
  end

  def previous_type
    @previous_type ||= query&.dig("previous_type")
  end

  def next_type
    @next_type     ||= query&.dig("next_type")
  end

  # Takes 1 to 3 milliseconds to run.
  def query
    return nil if @member.parent.nil?
    @query ||= ActiveRecord::Base.connection.execute("""
      SELECT * FROM (
        SELECT
          id,
          LAG(friendlier_id, 1)   over (order by position, id) AS previous_friendlier_id,
          LAG(type, 1)            over (order by position, id) AS previous_type,
          LEAD(friendlier_id,1)   over (order by position, id) AS next_friendlier_id,
          LEAD(type,1)            over (order by position, id) AS next_type
          FROM (
            SELECT
            id,
            friendlier_id,
            type,
            position
            FROM kithe_models
            WHERE parent_id = '#{@member.parent.id}'
        ) AS members
      ) AS all_members
      WHERE id = '#{@member.id}';
    """)[0]
  end
end

