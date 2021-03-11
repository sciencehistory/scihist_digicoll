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
      Work::PlaceLists::US_STATES.select { |st| st[1] == state }&.first&.first
    end

    def province_name
      return nil unless country == 'CA'
      Work::PlaceLists::CA_PROVINCES.select { |pr| pr[1] == province }&.first&.first
    end

    def country_name
      Work::PlaceLists::COUNTRIES.select { |co| co[1] == country }&.first&.first
    end
    def to_s
      [
        date,
        city,
        state_name,
        province_name,
        country_name,
      ].select(&:present?).join(", ")
    end

  end
end