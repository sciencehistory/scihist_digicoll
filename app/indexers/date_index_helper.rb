# Takes date metadata from a GenericWork, expands it into
# an array of integer years to be used to fill an int facet
# in solr for date range limit.
#
# Copied from https://github.com/sciencehistory/chf-sufia/blob/master/app/indexers/chf/generic_work_indexer/date_values.rb

class DateIndexHelper
  attr_reader :work
  def initialize(work)
    @work = work
  end

  def expanded_years
    @expanded_years ||= work.date_of_work.collect { |date_of_work| years_for_date_of_work(date_of_work) }.flatten
  end

  def min_year
    @minimum_year ||= expanded_years.min
  end

  def max_year
    @maximum_year ||= expanded_years.max
  end

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
end

