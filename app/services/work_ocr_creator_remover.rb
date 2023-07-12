# Given a work:
#   figures out which assets need OCR;
#   arranges for their OCR to be created (either via a job or immediately) or removed,
#   depending on the work's `ocr_requested`.
#
#   Ignores child works completely.
class WorkOcrCreatorRemover
  attr_reader :work

  # @param work [Work] Work to look at
  # can be used to update a progress UI.
  def initialize(work, ignore_missing_files:false)
    @ignore_missing_files = ignore_missing_files
    @work = work
  end

  def process
    if @work.ocr_requested
      image_assets.each { |a| maybe_add(a) }
    else
      image_assets.each { |a| maybe_remove(a) }
    end
  end

  private

  def maybe_add(asset)
    return if @ignore_missing_files && !asset.file.exists?

    # we need both of em!
    if asset.hocr.blank? || asset.file_derivatives[:textonly_pdf].blank?
      CreateAssetHocrJob.perform_later(asset) if asset.hocr.blank?
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
    # this kithe command will save record to, persisting the hocr=nil,
    # atomically concurrently safely making the change.
    asset.remove_derivatives(:textonly_pdf, allow_other_changes: true)
  end

  def image_assets
    @work.
      members.
      where(type: 'Asset').
      order(:position).
      select { |m| m.content_type.start_with?("image/") }
  end
end
