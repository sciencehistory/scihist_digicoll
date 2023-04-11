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
      image_assets.each { |a| a.update!(hocr: nil) }
    end
  end

  private

  def maybe_add(asset)
    return if @ignore_missing_files && !asset.file.exists?
    CreateAssetHocrJob.perform_later(asset) if asset.hocr.blank?
  end

  def image_assets
    @work.
      members.
      where(type: 'Asset').
      order(:position).
      select { |m| m.content_type.start_with?("image/") }
  end
end