# Used for several "standard" dates, that need to be
# a) present for sorting and b) follow YYYY-[-MM-DD] format.
# Opting against using this validator for date_of_work.rb dates,
# since the requirements for those are slightly more complex,
# e.g. they can be absent in certain cases depending on other metadata.
class StandardDateValidator < ActiveModel::Validator
  def validate(record)
    nice_date = /\A\d{4}(-\d{2}(-\d{2})?)?\z/
    options[:fields].each do |field|
      value = record.send(field)
      unless value =~ nice_date
        record.errors.add(field, "Must be of format YYYY[-MM-DD]")
      end
    end
  end
end