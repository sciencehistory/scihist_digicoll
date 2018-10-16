class Work::Creator
  TYPE_VOCAB = %w{after artist author addressee creator_of_work contributor engraver interviewee
                  interviewer manufacturer manner_of photographer printer printer_of_plates
                  publisher}

  include AttrJson::Model

  attr_json :type, :string
  attr_json :value, :string
end
