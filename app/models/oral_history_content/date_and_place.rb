class OralHistoryContent
  class DateAndPlace
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]
    attr_json :date,  :string
    attr_json :city, :string
    attr_json :state, :string
    attr_json :province, :string
    attr_json :country, :string

    def update_from_hash(hsh)
      self.date =         hsh['date']
      self.city =         hsh['city']
      self.state =        hsh['state']
      self.province =     hsh['province']
      self.country =      hsh['country']
    end

    def empty?
      [
        self.date,
        self.city,
        self.state,
        self.province,
        self.country
      ].none? { |val| val.present? }
    end
  end
end