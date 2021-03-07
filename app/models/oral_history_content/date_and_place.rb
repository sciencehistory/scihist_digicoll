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

    def state_name
      return nil unless country == 'US'
      ISO3166::Country.new(country).subdivisions[state]['translations']['en']
    end

    def province_name
      return nil unless country == 'CA'
      ISO3166::Country.new(country).subdivisions[province]['translations']['en']
    end

    def to_s
      [
        date,
        city,
        state_name,
        province_name,
        ISO3166::Country.new(country),
      ].select(&:present?).join(", ")
    end

  end
end