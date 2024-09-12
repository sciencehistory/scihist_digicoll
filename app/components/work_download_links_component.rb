# frozen_string_literal: true

# ON-PAGE download links for Work page, for whole-work downloads
class WorkDownloadLinksComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def has_searchable_pdf?
    return @has_searchable_pdf if defined?(@has_searchable_pdf)

    # we COULD use WorkShowOcrComponent to do a single-SQL query as to asset OCR status...
    # but it's a bit slow, ends up being like 1ms per 10 pages. Instead, for now
    # we're just going to go based on the ocr_requested? flag, meaning sometimes we'll
    # show searchable PDF when OCR may be queued in progress...
    @has_searchable_pdf = work.ocr_requested? # && !WorkShowOcrComponent.new(work).asset_ocr_count_warning?
  end

  def download_options
    pdf_option_args = if has_searchable_pdf?
      { label: "Searchable PDF", subhead: "may contain errors"}
    else
      {}
    end

    @download_options ||= WorkDownloadOptions.new(work: work, pdf_option_args: pdf_option_args).options
  end

  def download_button_label(download_option)
    case download_option.data_attrs[:derivative_type].to_s
    when "pdf_file" ; "Download PDF"
    when "zip_file" ; "Download ZIP"
    else "Download"
    end
  end
end
