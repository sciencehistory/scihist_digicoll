# Takes an PDF asset with `work_source_pdf` role, and a page number (1-based), and extracts
# a page image and hocr to create a new Asset
#
# By default will skip creation if an asset already exists for page. Or else pass in alternate
# on_existing_dup.
#
class CreatePdfPageImageAssetJob < ApplicationJob
  def perform(source_asset, page_num, on_existing_dup: "abort")
    argument_check(source_asset, page_num)

    new_asset = nil

    source_asset.file.download do |pdf_file|
      new_asset = PdfToPageImages.new(pdf_file.path).create_asset_for_page(
        page_num,
        work: source_asset.parent,
        source_pdf_sha512: source_asset.sha512,
        source_pdf_asset_pk: source_asset.id,
        on_existing_dup: on_existing_dup.to_sym
      )
    end

    # if this is page 1, set it as representative if needed....
    if page_num == 1 && (source_asset.parent.representative.nil? || source_asset.parent.representative.role == PdfToPageImages::SOURCE_PDF_ROLE)
       source_asset.parent.update!(representative: new_asset)
    end
  end

  protected

  def argument_check(source_asset, page_num)
    if source_asset.content_type != "application/pdf"
      raise ArgumentError.new("#{self.class.name} can only work with PDF source asset")
    end

    if !source_asset.stored?
      raise ArgumentError.new("#{self.class.name} requires a fully promoted stored source asset")
    end

    if page_num.to_i <= 0
      raise ArgumentError.new("#{self.class.name} requires a page_num argument that is an integer greater than 0")
    end
  end
end
