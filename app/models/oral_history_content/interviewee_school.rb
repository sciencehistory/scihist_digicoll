class OralHistoryContent
  class IntervieweeSchool
    include AttrJson::Model
    validates_presence_of :date
    validates_with StandardDateValidator, fields: [:date]
    validates_presence_of :institution
    attr_json :date,        :string
    attr_json :institution, :string
    attr_json :degree,      :string
    attr_json :discipline,  :string

    def update_from_hash(hsh)
      self.date =        hsh['date']
      self.degree =      hsh['degree']
      self.institution = hsh['institution']
      self.discipline =  hsh['discipline']
    end

  end
end