# Finds the next and previous members in a work.
# In cases where positions are noncontiguous, non-unique, or nil,
# you can still navigate through the members sequentially.
class MemberPreviousAndNextGetter
  # @param member [Kithe::Model]
  def initialize(member)
    @member = member
  end

  def next_url
    @next_url ||= url(:next)
  end

  def previous_url
    @previous_url ||= url(:previous)
  end

  private
  
  def url(previous_or_next)
    return nil unless @member.parent.present?
    if (neighbor_id = query["#{previous_or_next}_friendlier_id"])
      # ok, we have a neighbor. construct the right kind of link to it.
      neighbor_type = query["#{previous_or_next}_type"]
      if neighbor_type == 'Work'
        Rails.application.routes.url_helpers.admin_work_path(neighbor_id)
      elsif neighbor_type == 'Asset'
        Rails.application.routes.url_helpers.admin_asset_path(neighbor_id)
      end
    end
  end

  # Takes less than a millisecond.
  def query
    @query ||= ActiveRecord::Base.connection.execute("""
      SELECT * FROM (
        SELECT
          id,
          LAG  (friendlier_id, 1) over (order by position, id) AS previous_friendlier_id,
          LAG  (type, 1)          over (order by position, id) AS previous_type,
          LEAD (friendlier_id,1)  over (order by position, id) AS next_friendlier_id,
          LEAD (type,1)           over (order by position, id) AS next_type
          FROM (
            SELECT id, friendlier_id, type, position
            FROM kithe_models
            WHERE parent_id = '#{@member.parent.id}'
        ) AS members
      ) AS all_members
      WHERE id = '#{@member.id}';
    """.squish)[0]
  end
end

