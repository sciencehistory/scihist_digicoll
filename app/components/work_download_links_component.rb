# frozen_string_literal: true

# ON-PAGE download links for Work page, for whole-work downloads
#
# We use a list of DownloadOption elements, but format them on page -- and change name/subhead
# from usual in some cases.
class WorkDownloadLinksComponent < ApplicationComponent
  attr_reader :work, :download_options

  def initialize(work, download_options:)
    @work = work

    @download_options = download_options

    if has_searchable_pdf?
      # override some values in options
      @download_options.collect! do |option|
        if option.analyticsAction.to_s == "download_pdf"
          option.dup_with("Searchable PDF", subhead: "may contain errors")
        else
          option
        end
      end
    end
  end

  def has_searchable_pdf?
    return @has_searchable_pdf if defined?(@has_searchable_pdf)

    # we COULD use WorkShowOcrComponent to do a single-SQL query as to asset OCR status...
    # but it's a bit slow, ends up being like 1ms per 10 pages. Instead, for now
    # we're just going to go based on the ocr_requested? flag, meaning sometimes we'll
    # show searchable PDF when OCR may be queued in progress...
    @has_searchable_pdf = work.ocr_requested? # && !WorkShowOcrComponent.new(work).asset_ocr_count_warning?
  end


  def download_button_label(download_option)
    case download_option.data_attrs[:derivative_type].to_s
    when "pdf_file" ; "Download PDF"
    when "zip_file" ; "Download ZIP"
    else "Download"
    end
  end

  def download_file_icon(download_option)
    case download_option.data_attrs[:derivative_type].to_s
    when "pdf_file" ; helpers.file_earmark_pdf_fill_svg
    when "zip_file" ; helpers.file_earmark_zip_fill_svg
    else "x"
    end
  end
end
