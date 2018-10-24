class Work::Date
  include AttrJson::Model

  START_QUALIFIERS = [nil] + %w{before after century circa decade undated}
  FINISH_QUALIFIERS = [nil] + %w{before circa}

  validates_format_of :start, with: /\d{4}-\d{2}-\d{2}/, message: "must be of format YYYY-MM-DD"
  validates_format_of :finish, with: /\d{4}-\d{2}-\d{2}/, message: "must be of format YYYY-MM-DD", allow_blank: true


  attr_json :start, :string
  attr_json :start_qualifier, :string

  attr_json :finish, :string
  attr_json :finish_qualifier, :string

  attr_json :note, :string


end
