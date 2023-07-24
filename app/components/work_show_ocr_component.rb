# Display stats about work's OCR members.
class WorkShowOcrComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def assets_with_ocr
    assets_with_and_without_ocr.count {|a| a['has_ocr']}
  end

  def total_assets
    assets_with_and_without_ocr.length
  end

  def assets_with_and_without_ocr
    query = """SELECT
    (json_attributes->>'hocr' IS NOT NULL) AS has_ocr
    FROM kithe_models
    WHERE type = 'Asset'
    AND parent_id = '#{@work.id}'"""
    @assets_with_and_without_ocr ||= ActiveRecord::Base.
      connection.exec_query(query).to_a
  end

  def asset_ocr_count_warning?
    (work.ocr_requested? && assets_with_ocr != total_assets) ||
    (! work.ocr_requested? && assets_with_ocr > 0)
  end

  def work_language_warning?
    @work.ocr_requested? && ! AssetOcrCreator.suitable_language?(work)
  end

  def warnings?
    asset_ocr_count_warning? || work_language_warning?
  end
end
