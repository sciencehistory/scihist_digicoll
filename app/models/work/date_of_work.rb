class Work
  class DateOfWork
    include AttrJson::Model

    START_QUALIFIERS = %w{before after century circa decade undated}
    FINISH_QUALIFIERS = %w{before circa}

    validates :start_qualifier, inclusion: { in: START_QUALIFIERS, allow_blank: true }
    validates :finish_qualifier, inclusion: { in: FINISH_QUALIFIERS, allow_blank: true }
    validates_format_of :start, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]",
      unless: Proc.new { |d| d.start_qualifier == 'undated' }

    validates_absence_of :start,
      message: "should be left blank if you specify 'undated'.",
      if: Proc.new { |d| d.start_qualifier == 'undated' }

    validates_format_of :finish, with: /\A\d{4}(-\d{2}(-\d{2})?)?\Z/, message: "must be of format YYYY[-MM-DD]", allow_blank: true



    attr_json :start, :string
    attr_json :start_qualifier, :string

    attr_json :finish, :string
    attr_json :finish_qualifier, :string

    attr_json :note, :string


  end
end
