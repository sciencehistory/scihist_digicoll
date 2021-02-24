class OralHistoryContent
  class IntervieweeHonor
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]
    validates_presence_of :honor
    attr_json :date, :string
    attr_json :honor, :string

    def update_from_hash(hsh)
      self.date =         hsh['date']
      self.honor =        hsh['honor']
    end
  end
end