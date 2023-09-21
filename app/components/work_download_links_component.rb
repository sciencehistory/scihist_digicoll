# frozen_string_literal: true

# ON-PAGE download links for Work page, for whole-work downloads
class WorkDownloadLinksComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def has_searchable_pdf?
    return @has_searchable_pdf if defined?(@has_searchable_pdf)

    # we use WorkShowOcrComponent to do a single-SQL query as to asset OCR status
    @has_searchable_pdf = work.ocr_requested? && !WorkShowOcrComponent.new(work).asset_ocr_count_warning?
  end
end
