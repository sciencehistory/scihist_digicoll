# A Work can have one or more DateOfWork objects representing a date, or date range,
# or partial date. Including things like "the 1930s" or "May 1940 to June 1941"
#
# This class interprets/expands those DateOfWork objects into more specific things
# that we need for Solr indexing.
#
# #expanded_years is an array of years, any year that might be represented
# by any dates included, that we use for some solr fields to facet upon
#
# #min_date and #max_date are actual Ruby date objects, the latest or
# earliest dates that might be represented by the DateOfWork set,
# that we use for Solr fields to sort on.
#
class DateIndexHelper
  attr_reader :work
  def initialize(work)
    @work = work
  end

  # An array of int, all the years that might be included by any dates/ranges in work
  # We use for a year facet value
  def expanded_years
    @expanded_years ||= work.date_of_work.collect { |date_of_work| years_for_date_of_work(date_of_work) }.flatten
  end


  # @return [Date] the earliest date in the work -- for dates effectively
  #   representing ranges,the earliest possible date in the range is it.
  #
  #   Returns nil if none can be found because of no dates or malformed dates.
  def min_date
    work.date_of_work.collect do |date_of_work|
      start, start_qualifier, finish, finish_qualifier = date_of_work.start, date_of_work.start_qualifier, date_of_work.finish, date_of_work.finish_qualifier

      case start_qualifier
      when "Undated"
        nil
      when "decade"
        complete_min_date(start.strip.slice(0..2)) # send first three year digits
      when "century"
        complete_min_date(start.strip.slice(0..1)) # send first two year digits
      else
        # For all other types of start date (circa, before, after, as well as blank)
        # we're just going to index it as the date we've got, if we've got one.
        complete_min_date(start)
      end
    end.compact.min
  end

  # @return [Date] The latest date in the work -- for dates effectively
  #    representing ranges, the latest possible date in the range is it.
  #
  #    Returns nil if none can be found because of no dates or malformed dates.
  def max_date
    work.date_of_work.collect do |date_of_work|
      start, start_qualifier, finish, finish_qualifier = date_of_work.start, date_of_work.start_qualifier, date_of_work.finish, date_of_work.finish_qualifier

      if finish.present?
        operative_date, operative_qualifier = finish, finish_qualifier
      else
        operative_date, operative_qualifier = start, start_qualifier
      end

      case operative_qualifier
      when "Undated"
        nil
      when "decade"
        complete_max_date(operative_date.strip.slice(0..2)) # send first three year digits
      when "century"
        complete_max_date(operative_date.strip.slice(0..1)) # send first two year digits
      else
        # For all other types of start date (circa, before, after, as well as blank)
        # we're just going to index it as the date we've got, if we've got one.
        complete_max_date(operative_date)
      end
    end.compact.max
  end

  private

  # helper method for expanded_years, take a single DateOfWork and expand it into
  # all the years that might be included by dates referenced.
  def years_for_date_of_work(repo_d)
    start, start_qualifier, finish, finish_qualifier = repo_d.start, repo_d.start_qualifier, repo_d.finish, repo_d.finish_qualifier

    if start.nil? || start.blank?
      return []
    end

    case start_qualifier
    when "Undated"
      # We're ignoring finish here, if start is undated, it's undated buddy.
      []
    when "decade"
      # We're ignoring finish_date in this case
      first_three = start.strip.slice(0..2)
      return [] unless first_three =~ /\A\d+\Z/ # not a good date

      return ((first_three + "0").to_i .. (first_three + "9").to_i).to_a
    when "century"
      # We're ignoring finish_date in this case
      first_two = start.strip.slice(0..1)
      return [] unless first_two =~ /\A\d+\Z/ # not a good date

      return ((first_two + "00").to_i .. (first_two + "99").to_i).to_a
    when /\A\s*(\d\d\d\d)\s*-\s*(\d\d\d\d)/
      # we have a date range in start date, just use that ignore finish date
      # Catalogers aren't _supposed_ to enter this, but the 'hint' is
      # confusing and I think some may have.
      return ($1.to_i .. $2.to_i).to_a
    end

    # For all other types of start date (circa, before, after, as well as blank)
    # we're just going to index it as the date we've got, if we've got one.
    start_year = start.slice(0..3)
    return [] unless start_year =~ /\A\d+\Z/ # not a good date
    start_year = start_year.to_i

    finish_year =  (finish || "").slice(0..3).to_i # will be 0 if was blank or non-numeric

    # If finish year is before start year, or empty (in which case it'll be 0),
    # just use start date, best we can do.
    if finish_year <= start_year
      return [start_year]
    else
      # we have both years, ignore 'before' or 'circa' qualifiers
      # on finish, don't know what we'd do with those, just treat it
      # like a year.
      return (start_year..finish_year).to_a
    end
  end

  # Helper method for min_date, completes partial dates into a ruby Date
  #
  # Can pass in a yyyy-mm-dd date, OR a partial one:
  #
  # * \d\d (century, eg `20`)
  # * \d\d\d (decade, eg `193`)
  # * \d\d\d\d (just year, `1973`)
  # * \d\d\d\d-\d\d (just year and month, `2020-09`)
  # * \d\d\d\d-\d\d-\d\d (full date, 2020-04-21)
  #
  # @ returns [Date] representing the MINIMUM possible date for input that may
  #   represent a date. Like for `193` (decade), that means 1930-01-01
  #   Returns nil if bad unparseable unexpected input.
  #
  def complete_min_date(date_str)
    unless date_str && date_str =~ /(\d\d\d?\d?)(?:-(\d\d))?(?:-(\d\d))?/
      return nil # malformed date
    end

    year  = $1
    month = $2
    day   = $3

    if year.length == 2 # century
      Date.iso8601("#{date_str}00-01-01")
    elsif year.length == 3 #decade
      Date.iso8601("#{date_str}0-01-01")
    else
      # full year, maybe with month, maybe with date
      month ||= "01"
      day ||= "01"
      Date.iso8601("#{year}-#{month}-#{day}")
    end
  rescue Date::Error
    nil
  end

  # Helper method for max_date, completes partial dates into a ruby Date.
  #
  # like complete_min_date, but returns the date representing the MAXIMUM
  # possible date for input that may represent a date.
  #
  # @returns [Date] represneting MAXIMIM possible date for input,
  #   like for `193` (decade), that means `1939-12-31`. Returns
  #   nil if bad, unparseable, or unexpected input.
  def complete_max_date(date_str)
    unless date_str && date_str =~ /(\d\d\d?\d?)(?:-(\d\d))?(?:-(\d\d))?/
      return nil # malformed date
    end

    year  = $1
    month = $2
    day   = $3

    if year.length == 2 # century
      Date.iso8601("#{date_str}99-12-31")
    elsif year.length == 3 #decade
      Date.iso8601("#{date_str}9-12-31")
    elsif day.nil?
      month ||= "12" # maybe we don't have month either

      # have to auto-complete to last day in month, which
      # we can have date class figure out for us this way:
      Date.iso8601("#{year}-#{month}-01").next_month.prev_day
    else
      Date.iso8601("#{year}-#{month}-#{day}")
    end
  rescue Date::Error
    nil
  end
end

