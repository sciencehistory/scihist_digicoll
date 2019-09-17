# Takes an array of `Work::Date` objects (generally from `some_work.date_of_work`),
# and formats them for display to the user.
#
#     DateDisplayFormatter.new(work.date_of_work).display_dates
#     # => Array of strings, each being a human presentable date/range, like "1901", or "after 1950 -- circa 1990"
#
# Copied from old app chf-sufia/app/presenters/chf/dates_of_work_for_display.rb
class DateDisplayFormatter

  BEFORE = "before"
  AFTER = "after"
  CENTURY = "century"
  CIRCA = "circa"
  DECADE = "decade"
  UNDATED = "undated"

  def initialize(dates_of_work)
    @dates_for_display = dates_of_work.sort_by do |date|
      date.start || "0"
    end.collect {|d| display_label(d)}
  end

  #Return an array of strings, each containing a formatted date.
  def display_dates
    @dates_for_display
  end

  private

  def display_label(date_of_work)
    start_string = qualified_date(date_of_work.start,
      date_of_work.start_qualifier)
    finish_string = qualified_date(date_of_work.finish,
      date_of_work.finish_qualifier)

    if finish_string.blank?
      date_string = start_string
    else
      # careful, this is an en dash:
      date_string = [start_string, finish_string].compact.join(" – ")
    end

    if date_of_work.note.present?
      date_string = "#{date_string} (#{date_of_work.note})"
    end

    # Want to capitalize first letter only, and only if it's in position 0
    if date_string && date_string[0] =~ /\w/
      date_string = date_string.slice(0,1).capitalize + date_string.slice(1..-1)
    end

    date_string
  end

  # Some normalization of a yyyy-mm-dd date string to a human date string:
  # * Use English month abbreviation instead of numeric month
  # * Eliminate leading zeroes on years
  def humanize_date_str(date_given)
    return date_given if date_given.blank?

    ymd_arr = date_given.split("-")

    ymd_arr[0].gsub!(/\A0+/, '')

    if ymd_arr.length > 1
      month_str = Date::ABBR_MONTHNAMES[ymd_arr[1].to_i] || ymd_arr[1]
      ymd_arr[1] = month_str
    end

    return ymd_arr.join('-')
  end

  def qualified_date(date, qualifier)
    begin
      int_date_value = Integer(date)
    rescue
      int_date_value = nil
    end

    date = humanize_date_str(date)

    if qualifier == (BEFORE) || qualifier == (AFTER) || qualifier == (CIRCA)
      "#{qualifier} #{date}"
    elsif qualifier ==  DECADE
      if int_date_value == nil or int_date_value % 10 != 0 or int_date_value % 100 == 0
        #for non-obvious decades starting in e.g. 1912 or 1800 or "way back when"
        "decade starting #{date}"
      else
        #ordinary decades (e.g. 1910s)
        "#{date}s"
      end
    elsif qualifier ==  CENTURY
      if int_date_value == nil  or int_date_value % 100 != 0
        "century starting #{date}"
      else
        "#{date}s"
      end
    elsif qualifier ==  UNDATED
      qualifier
    elsif date.present?
      date
    else
      ""
    end
  end # qualified_date
end # class
