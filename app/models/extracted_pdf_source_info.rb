class ExtractedPdfSourceInfo
  include AttrJson::Model

  # 1-based index of page extracted from source PDF
  # used for identifying if a page already exists on creation
  attr_json :page_index, :integer
  validates :page_index, comparison: { greater_than: 0 }

  attr_json :source_pdf_sha512, :string
  attr_json :source_pdf_asset_pk, :string
end
