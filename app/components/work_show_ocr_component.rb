# Display stats about extracted `hocr` text in work's members, for either OCR or PDF extraction.
#
# Identify mismatches betweene expected `hocr` text and actual
#
# Displayed in a tab on work admin page?
class WorkShowOcrComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def heading_label
    if @work.ocr_requested?
      "OCR"
    elsif @work.pdf_text_extraction?
      "PDF Text"
    else
      "Text extraction"
    end
  end


  def assets_with_ocr_count
    @assets_with_ocr ||= assets_with_and_without_ocr.count {|a| a['has_ocr']}
  end

  def assets_with_ocr_suppressed_count
    @assets_with_ocr_suppressed ||= assets_with_and_without_ocr.count {|a| a['suppress_ocr']}
  end

  def total_assets_count
    assets_with_and_without_ocr.length
  end

  def assets_with_extracted_pdf_page_role_count
    @assets_with_extracted_pdf_page_role ||= assets_with_and_without_ocr.count {|a| a['role'] == PdfToPageImages::EXTRACTED_PAGE_ROLE }
  end

  def assets_with_source_pdf_role
    @assets_with_source_pdf_role ||= @work.members.find_all { |a| a.is_a?(Asset) && a['role'] == PdfToPageImages::SOURCE_PDF_ROLE }
  end

  def assets_with_source_pdf_role_count
    @assets_with_source_pdf_role_count ||= assets_with_source_pdf_role.count
  end

  def source_pdf_page_count
    return @source_pdf_page_count if defined? @source_pdf_page_count

    @source_pdf_page_count = assets_with_source_pdf_role_count == 1 && assets_with_source_pdf_role.first.file_metadata["page_count"]
  end


  # Assets with suppress_ocr are not shown as having OCR,
  # even if there is currently something in the `hocr` field.
  def assets_with_and_without_ocr
    @assets_with_and_without_ocr ||= begin
      query = """

        SELECT
          (
            derived_metadata_jsonb ->> 'hocr' IS NOT NULL
            and
            coalesce(json_attributes ->> 'suppress_ocr', 'false') != 'true'
          ) has_ocr,
          (
            json_attributes ->> 'suppress_ocr' = 'true'
          ) suppress_ocr,
          role
        FROM kithe_models
        WHERE type = 'Asset'
        AND parent_id = '#{@work.id}'

      """
      ActiveRecord::Base.connection.exec_query(query).to_a
    end
  end




  def asset_ocr_count_warning?
    work.ocr_requested? &&
    (
      (assets_with_ocr_count + assets_with_ocr_suppressed_count)!= total_assets_count ||
      assets_with_extracted_pdf_page_role_count != 0 ||
      assets_with_source_pdf_role_count != 0
    )
  end

  def extra_ocr_warning?
    (work.text_extraction_mode.nil? && (assets_with_ocr_count >= 0))
  end

  def work_language_warning?
    @work.ocr_requested? && ! AssetOcrCreator.suitable_language?(work)
  end

  def pdf_extraction_count_warning?
    @work.pdf_text_extraction? &&
    (
      (assets_with_extracted_pdf_page_role_count != assets_with_ocr_count) ||
      assets_with_source_pdf_role_count != 1
    ) ||
    !(source_pdf_page_count.present? && source_pdf_page_count > 0 && assets_with_extracted_pdf_page_role_count == source_pdf_page_count)
  end

  def warnings?
    asset_ocr_count_warning? || work_language_warning? || extra_ocr_warning? || pdf_extraction_count_warning?
  end
end
