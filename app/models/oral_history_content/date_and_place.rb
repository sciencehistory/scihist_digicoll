class OralHistoryContent
  class DateAndPlace
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]
    attr_json :date,  :string
    attr_json :city, :string
    attr_json :state, :string
    attr_json :province, :string
    attr_json :country, :string
  end
end