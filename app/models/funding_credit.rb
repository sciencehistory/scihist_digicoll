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
    },
    "asms" => {
      label: "American Society for Mass Spectrometry",
      path: "ASMS.jpg"
    },
    "beckman" => {
      label: "Beckman Foundation",
      path: "Beckman.jpg"
    },
    "clir" => {
      label: "CLIR",
      path: "clir-red-symbol.png"
    },
    "cns_asu" => {
      label: "CNS-ASU",
      path: "CNS-ASU.jpg"
    },
    "cusp" => {
      label: "cusp",
      path: "CUSP.jpg"
    },
    "moore" => {
      label: "GordonBettyMoore",
      path: "GordonBettyMoore.png"
    },
    "life_sciences_foundation" => {
      label: "Life Sciences Foundation",
      path: "Life_Sciences_Foundation.jpg"
    },
    "nih" => {
      label: "NIH",
      path: "nih.jpg"
    },
    "newman" => {
      label: "Newman Numismatic Portal",
      path: "Newman-Numismatic-Portal.jpg"
    },
    "nhprc" => {
      label: "nhprc",
      path: "NHPRC.jpg"
    },
    "nsf" => {
      label: "NSF",
      path: "National-Science-Foundation-logo.png"
    },
    "pew" => {
      label: "Pew Charitable Trusts",
      path: "PEW_Charitable_Trusts.jpg"
    }
  }.freeze

  def self.image_collection_input
    @image_collection_input ||= IMAGES.collect do |key, definition|
      [definition[:label], key]
    end.sort_by { |label,key| label }
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
