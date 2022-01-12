# Embedded AttrJson::Model intended for use with Collections
class FundingCredit
  include AttrJson::Model

  attr_json :name, :string
  attr_json :image, :string
  attr_json :url, :string

  # paths in app/assets/images/funding_credit, should be square,
  # prob should be jpg or png
  # Key is what will be in DB.
  IMAGES = {
    "test" => {
      label: "Test Graphic",
      path: "test.jpg"
    }
  }.freeze

  def self.image_collection_input
    IMAGES.collect do |key, definition|
      [definition[:label], key]
    end
  end

  validates :name, presence: true
  validates :image, inclusion: { in: IMAGES.keys.collect(&:to_s), allow_blank: true }
  validates :url, format: {
    with: /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/,
    allow_blank: true,
    message: "must be valid http or https URL"}

  def image_path
    File.join("funding_credit", IMAGES[image][:path])
  end
end
