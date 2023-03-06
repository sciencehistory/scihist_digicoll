# Takes a date of the form yyyy-mm-dd or yyyy-mm or yyyy
#   (that is a simple basic variety of EDTF -- https://www.loc.gov/standards/datetime/)
#
# And formats it into human-readable with month-names.
#
# Can also take two of them, and will format as a range, with word " to ", as
# per legacy OH behvior.
#
# WARNING: This class is not fully internationalized for non-English locales,
# that's hard and we didn't need it now.
#
# Developed for use with Oral History Biographical metadata, but can
# be used anywhere.
#
#    FormatSimpleDate.new("2021-01-01").display
#    FormatSimpleDate.new("1975-01-01", "1987-04").display
#    FormatSimpleDate.new("1975-01-01", nil).display
class FormatSimpleDate
  attr_reader :start_date, :end_date

  def initialize(start_date, end_date=nil)
    @start_date = start_date
    @end_date = end_date

    # don't display it as a range if end date and start date are identical
    if @start_date == @end_date
      @end_date = nil
    end
  end

  def display
    [human_format(start_date), human_format(end_date)].compact.join(" to ")
  end

  private

  def human_format(edtf)
    unless edtf && edtf =~ /\d\d\d\d(-\d\d(-\d\d)?)?/
      return nil
    end

    num_parts = edtf.count("-") + 1

    if num_parts == 1
      # year only
      return edtf
    elsif num_parts == 2
      # year and month, pretend it's first of the month, then
      # format with month and year only
      Date.strptime(edtf, '%Y-%m').strftime('%B %Y')
    else
      # year-month-day, we can parse it and use I18n :long to output
      # it.
      I18n.l(Date.strptime(edtf, '%Y-%m-%d'), format: :long)
    end
  end
end
