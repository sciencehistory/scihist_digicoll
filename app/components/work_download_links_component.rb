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

  def has_downloadable_zip?
    return @has_downloadable_zip if defined?(@has_downloadable_zip)

    # We use DownloadDropdownComponent to try to decide if it's going to have a ZIP link or not
    # using same logic it will...
    @has_downloadable_zip = DownloadDropdownComponent.work_has_multiple_published_images?(work)
  end

  def pdf_download_option
    # We don't actually use label, but want to get attributes out
    @zip_download_option ||= DownloadOption.for_on_demand_derivative(
        label: "", derivative_type: "pdf_file", work_friendlier_id: work.friendlier_id
      )
  end

  def zip_download_option
    # We don't actually use label, but want to get attributes out
    DownloadOption.for_on_demand_derivative(
      label: "", derivative_type: "zip_file", work_friendlier_id: work.friendlier_id
    )
  end
end
