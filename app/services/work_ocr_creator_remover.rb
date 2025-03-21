# Ensures that a work's OCR data is consistent with it's Work#ocr_requested boolean value
#
# Will add OCR data if ocr_requested? but ocr data is missing
#
# Will remove OCR data is !ocr_requested? but present.
#
# Some work may be done asynchronously by queing background jobs, as OCR is slow.
#
# Warning:
#   Currently ignores child works completely.
#
# @example
#
#    WorkOcrCreatorRemover.new(work).process
#
#
class WorkOcrCreatorRemover
  attr_reader :work

  # @param work [Work] Work to look at
  # can be used to update a progress UI.
  def initialize(work, ignore_missing_files:false)
    @ignore_missing_files = ignore_missing_files
    @work = work
  end

  def process
    if @work.ocr_requested?
      unless AssetOcrCreator.suitable_language?(work)
        Rails.logger.warn("#{self.class}: OCR enabled for work #{work.friendlier_id}, but it does not have suitable languages: #{work.language.inspect}")
        return
      end

      image_assets.each do |a|
        if a.suppress_ocr
          maybe_remove(a)
        else
          maybe_add(a)
        end
      end
    elsif @work.text_extraction_mode.blank? # not PDF extraction either
      image_assets.each { |a| maybe_remove(a) }
    end
  end

  private

  def maybe_add(asset)
    return if @ignore_missing_files && !asset.file.exists?

    # we need both of em!
    if asset.hocr.blank? || asset.file_derivatives[:textonly_pdf].blank?
      CreateAssetOcrJob.perform_later(asset)
    end
  end

  # Even if there are no changes made to save, ActiveRecord will
  # still open and close a transaction, which takes some time
  # and load on DB, don't do it unless we actually have things to remove.
  #
  def maybe_remove(asset)
    # don't need it if we already don't have hocr or textonly_pdf
    return if !asset.hocr && !asset.file_derivatives[:textonly_pdf]

    asset.hocr = nil
    # this next kithe command will save record too, persisting the hocr=nil,
    # atomically concurrently safely making the change.
    asset.remove_derivatives(:textonly_pdf, allow_other_changes: true)
  end

  def image_assets
    # ignore extracted_pdf_page Assets entirely, not our responsibilty, they are the product of
    # of a PDF page render, and in our present use cases should not get OCR'd, and if they did
    # get OCR'd it might accidentally overwrite a PDF text extraction stored in hocr field
    @work.
      members.
      where(type: 'Asset').
      where("role is null OR role != ?", PdfToPageImages::EXTRACTED_PAGE_ROLE).
      order(:position).
      select { |m| m.content_type&.start_with?("image/") }
  end
end
