class OralHistoryContent
  class IntervieweeJob
    include AttrJson::Model
    validates_presence_of :institution
    validates_presence_of :start
    validates_with StandardDateValidator, fields: [:start, :end]
    attr_json :start,       :string
    attr_json :end,         :string
    attr_json :institution, :string
    attr_json :role,        :string

    def update_from_hash(hsh)
      self.start =        hsh['start']
      self.end =          hsh['end']
      self.institution =  hsh['institution']
      self.role =         hsh['role']
    end

  end
end