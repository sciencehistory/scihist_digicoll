class Collection < Kithe::Collection
  validates :related_url, array_inclusion: {
    proc: ->(v) { ScihistDigicoll::Util.valid_url?(v) } ,
    message: "is not a valid url: %{rejected_values}"
  }

  attr_json :description, :text
  attr_json :related_url, :string, array: true
end
