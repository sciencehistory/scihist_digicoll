class OralHistoryContent

  # Used for Birth and Death info
  class DateAndPlace
    include AttrJson::Model

    attr_json :date,  :string
    attr_json :city, :string
    attr_json :state, :string
    attr_json :province, :string
    attr_json :country, :string

    validates_with StandardDateValidator, fields: [:date]

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

    def displayable_values
      [
        date,
        city,
        state_name,
        province_name,
        country_name,
      ].collect(&:presence).compact
    end

    def to_s
      displayable_values.join(", ")
    end
  end
end
