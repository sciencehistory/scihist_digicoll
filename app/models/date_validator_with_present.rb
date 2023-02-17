# A variation on the superclass, but also considers "present" a valid date.
# Currently only used in IntervieweeJob.
class DateValidatorWithPresent < StandardDateValidator
  def format_error_string
    "#{super} or 'present'"
  end

  def accept_value?(value)
    value == "present" || super(value)
  end
end
