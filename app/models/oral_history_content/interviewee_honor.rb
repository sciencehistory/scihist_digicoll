class OralHistoryContent
  class IntervieweeHonor
    include AttrJson::Model

    attr_json_config(unknown_key: :strip)

    attr_json :start_date, :string # date as yyyy(-mm(-dd))
    attr_json :end_date, :string # date as yyyy(-mm(-dd))
    attr_json :honor, :string

    validates_with StandardDateValidator, fields: [:start_date, :end_date]
  end
end
