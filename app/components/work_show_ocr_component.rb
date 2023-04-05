# Display the provenance of a work on the front end:
# WorkProvenanceComponent.new(work.provenance).display
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
    query = "SELECT json_attributes ? 'hocr' AS has_ocr FROM kithe_models WHERE type = 'Asset' AND parent_id = '#{@work.id}'"
    @assets_with_and_without_ocr ||= ActiveRecord::Base.
      connection.exec_query(query).to_a
  end
end
