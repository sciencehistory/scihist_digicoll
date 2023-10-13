# Finds the next and previous members in a work.
class MemberPreviousAndNextGetter
  attr_reader :asset

  # @param member [Kithe::Model]
  def initialize(member)
    @member = member
  end

  def previous_and_next
    {
       previous: both.find{|m| m.position < @member.position },
       next:     both.find{|m| m.position > @member.position }
    }
  end

  # Orders the members in @member.parent by position,
  # then returns the previous and next members in that ordering.
  #
  # Does not assume the positions are consecutive integers.
  # Returns between zero and two Kithe::Model s, in an arbitrary order.
  def both
    @both ||= begin
      Kithe::Model.where("""
      id in (
        SELECT
          UNNEST(ARRAY[previous_id, next_id]) as id
        FROM 
        (
          SELECT
          id,
          LAG(id,   1) over (order by position) as previous_id,
          LEAD(id,  1) over (order by position) as next_id
          FROM
          (
            SELECT
              id,
              position
              FROM kithe_models
              WHERE parent_id = '#{@member.parent.id}'
              ORDER BY position
          ) as members
        ) as members_with_previous_and_next
        WHERE id = '#{@member.id}'
      )
      """)
    end
  end

end

