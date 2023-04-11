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
    # Check that the value exists and is a string.
    has_ocr_sql = "json_typeof((json_attributes->'hocr')::json)='string'"

    query = """SELECT #{has_ocr_sql}
    AS has_ocr
    FROM kithe_models
    WHERE type = 'Asset'
    AND parent_id = '#{@work.id}'"""
    @assets_with_and_without_ocr ||= ActiveRecord::Base.
      connection.exec_query(query).to_a
  end
end
