class Work
  class AdditionalCredit
    include AttrJson::Model

    ROLES = ['photographed_by']
    NAMES = [
      'Douglas Lockard',
      'Gregory Tobias',
      'Mark Backrath',
      'Penn School of Medicine',
      'Will Brown'
    ]

    # allow_blank keeps us from having double validation error messages for
    # presence and inclusion.
    validates :role, presence: true, inclusion:
      { in: ROLES,
        allow_blank: true,
        message: "%{value} is not a valid credit role" }
    validates :name, presence: true, inclusion:
      { in: NAMES,
        allow_blank: true,
        message: "%{value} is not a valid credit name" }

    attr_json :role, :string
    attr_json :name, :string
  end
end
