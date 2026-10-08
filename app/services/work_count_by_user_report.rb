# Work creation and publication counts for each month in a range, per account (the
# created_by / last_published_by User's name, else email) plus an [ALL] row for the month.
# Works with no recorded user are counted under {UNRECORDED}. Months are in the app time zone.
#
# aggregate SQL and computation definitely by Claude
class WorkCountByUserReport
  ALL = "[ALL]"
  UNRECORDED = "{UNRECORDED}"
  ACCOUNT_SQL = "COALESCE(NULLIF(users.name, ''), users.email, '#{UNRECORDED}')".freeze

  # One month and account's counts.
  class Row
    attr_reader :month, :account, :created_count, :published_count

    def initialize(month:, account:, created_count:, published_count:)
      @month = month
      @account = account
      @created_count = created_count
      @published_count = published_count
    end
  end

  attr_reader :from_month_start, :to_month_end

  # @param from_month [Date] first month, inclusive (any day in it)
  # @param to_month [Date] last month, inclusive (any day in it)
  def initialize(from_month:, to_month:)
    @from_month_start = from_month.beginning_of_month.beginning_of_day
    @to_month_end = to_month.end_of_month.end_of_day
  end

  # @return [Array<Row>] oldest month first; within a month [ALL], then {UNRECORDED}, then names
  def rows
    created_counts = counts(:created_at, :created_by)
    published_counts = counts(:published_at, :last_published_by)

    start_days_of_included_months.flat_map do |month|
      accounts = accounts_for_month(month, created_counts, published_counts)

      accounts.map do |account|
        Row.new(month: month,
                account: account,
                created_count: count_for(created_counts, month, account),
                published_count: count_for(published_counts, month, account))
      end
    end
  end

  private

  # @return [Array<Date>] the first day of each month in the range, oldest first
  def start_days_of_included_months
    @start_days_of_included_months ||= (from_month_start.to_date..to_month_end.to_date).select { |date| date.day == 1 }
  end

  # [ALL] first, then every account with a created or published count that month.
  def accounts_for_month(month, created_counts, published_counts)
    all_keys = created_counts.keys | published_counts.keys
    accounts = all_keys.filter_map { |key_month, account| account if key_month == month }

    [ALL] + sort_accounts(accounts)
  end

  # Each work has exactly one account, so [ALL] is the sum over the month's accounts.
  #
  # @param counts [Hash] { [first day of month Date, account] => count }, as from #counts
  # @param month [Date] first day of the month
  # @param account [String] account label, or ALL
  # @return [Integer] 0 if there are none
  def count_for(counts, month, account)
    if account == ALL
      counts.sum { |(m, _), count| m == month ? count : 0 }
    else
      counts.fetch([month, account], 0)
    end
  end

  def sort_accounts(accounts)
    accounts.sort_by { |account| [account == UNRECORDED ? 0 : 1, account.downcase] }
  end

  # @return [Hash] { [month Date, account] => count }
  def counts(date_column, user_association)
    Work.left_joins(user_association).
      where(date_column => from_month_start..to_month_end).
      group(Arel.sql(month_sql(date_column)), Arel.sql(ACCOUNT_SQL)).
      count.
      transform_keys { |month, account| [Date.parse(month), account] }
  end

  def month_sql(date_column)
    Work.sanitize_sql_array([
      "to_char(date_trunc('month', #{Work.table_name}.#{date_column} AT TIME ZONE 'UTC' AT TIME ZONE ?), 'YYYY-MM-DD')",
      Time.zone.tzinfo.name
    ])
  end
end
