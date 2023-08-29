# Display stats about work's OCR members.
class WorkShowOcrComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def assets_with_ocr
    @assets_with_ocr ||= assets_with_and_without_ocr.count {|a| a['has_ocr']}
  end

  def assets_with_ocr_suppressed
    @assets_with_ocr_suppressed ||= assets_with_and_without_ocr.count {|a| a['suppress_ocr']}
  end

  def total_assets
    assets_with_and_without_ocr.length
  end

  # Assets with suppress_ocr are not shown as having OCR,
  # even if there is currently something in the `hocr` field.
  def assets_with_and_without_ocr
    @assets_with_and_without_ocr ||= begin
      query = """

        SELECT
          (
            json_attributes ->> 'hocr' IS NOT NULL
            and
            coalesce(json_attributes ->> 'suppress_ocr', 'false') != 'true'
          ) has_ocr,
          (
            json_attributes ->> 'suppress_ocr' = 'true'
          ) suppress_ocr
        FROM kithe_models
        WHERE type = 'Asset'
        AND parent_id = '#{@work.id}'

      """
      ActiveRecord::Base.connection.exec_query(query).to_a
    end
  end




  def asset_ocr_count_warning?
    (work.ocr_requested? && (assets_with_ocr + assets_with_ocr_suppressed)!= total_assets) ||
    (! work.ocr_requested? && assets_with_ocr > 0)
  end

  def work_language_warning?
    @work.ocr_requested? && ! AssetOcrCreator.suitable_language?(work)
  end

  def warnings?
    asset_ocr_count_warning? || work_language_warning?
  end
end
