# Used for several "standard" dates, that need to be
# a) present for sorting and b) follow YYYY-[-MM-DD] format.
# Opting against using this validator for date_of_work.rb dates,
# since the requirements for those are slightly more complex,
# e.g. they can be absent in certain cases depending on other metadata.
#
# Does allow empty date, add a presence validator if you want
# it to be required too!
class StandardDateValidator < ActiveModel::Validator

  def is_nice_date?(value)
    nice_date = /\A\d{4}(-\d{2}(-\d{2})?)?\z/
    value =~ nice_date
  end

  def format_error_string
    "Must be of format YYYY[-MM-DD]"
  end

  def accept_value?(value)
    value.blank? || is_nice_date?(value)
  end

  def validate(record)
    options[:fields].each do |field|
      value = record.send(field)
      unless accept_value?(value)
        record.errors.add(field, format_error_string)
      end
    end
  end
end
