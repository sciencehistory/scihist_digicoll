# Cumulative and per-month Work counts for the Work Count Report, as a list of MonthCounts
# objects, oldest first. Covers the `month_count` full calendar months before the current
# one. Computed in a single query using FILTERed aggregates.
#
#   total   = works with the date on or before the end of that month
#   current = works with the date within that month
#
# Works published before we tracked published_at have published = true but no
# published_at. We don't know when, so they are added to the Published total
# of every month ending after the earliest known published_at.
class WorkCountReport
  # Cumulative totals, and counts within just that one month, for each date column.
  class MonthCounts
    attr_reader :starts_on, :created_total, :created_current, :published_total, :published_current

    def initialize(starts_on:, created_total:, created_current:, published_total:, published_current:)
      @starts_on = starts_on
      @created_total = created_total
      @created_current = created_current
      @published_total = published_total
      @published_current = published_current
    end
  end

  COLUMNS = { created: :created_at, published: :published_at }.freeze

  attr_reader :month_count, :today

  def initialize(month_count: 6, today: Time.zone.today)
    @month_count = month_count
    @today = today
  end

  # @return [Array<MonthCounts>] oldest first
  def months_with_counts
    *counts, min_published_at, undated_published_count = Work.pick(*aggregates.map { |sql| Arel.sql(sql) })

    month_starts.zip(counts.each_slice(COLUMNS.size * 2)).map do |month_start, month_counts|
      created_total, created_current, published_total, published_current = month_counts
      published_total += undated_published_count if min_published_at && month_start.next_month > min_published_at
      MonthCounts.new(starts_on: month_start.to_date, created_total:, created_current:, published_total:, published_current:)
    end
  end

  private

  # Oldest first; the last is the month before the current one.
  def month_starts
    @month_starts ||= (1..month_count).map { |n| today.beginning_of_month.prev_month(n).in_time_zone }.reverse
  end

  # Flat list: for each month, for each column, total then current; then the
  # earliest published_at, then the count of published works without published_at.
  def aggregates
    month_aggregates + [
      "MIN(published_at)",
      "COUNT(*) FILTER (WHERE published AND published_at IS NULL)"
    ]
  end

  def month_aggregates
    month_starts.flat_map do |month_start|
      month_end = month_start.next_month
      COLUMNS.values.flat_map do |column|
        [
          Work.sanitize_sql_array(["COUNT(*) FILTER (WHERE #{column} < ?)", month_end]),
          Work.sanitize_sql_array(["COUNT(*) FILTER (WHERE #{column} >= ? AND #{column} < ?)", month_start, month_end])
        ]
      end
    end
  end
end
