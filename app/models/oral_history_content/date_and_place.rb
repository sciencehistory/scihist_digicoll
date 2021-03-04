#require "countries"
class OralHistoryContent
  class DateAndPlace
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]
    attr_json :date,  :string
    attr_json :city, :string
    attr_json :state, :string
    attr_json :province, :string
    attr_json :country, :string

    def to_s
      [
        city,
        state,
        province,
        ISO3166::Country.new(country),
        date,
      ].select(&:present?).join(", ")
    end

  end
end