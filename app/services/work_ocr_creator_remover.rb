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
    if @work.ocr_requested
      if AssetOcrCreator.suitable_language?(work)
        image_assets.each do |a|
          if a.suppress_ocr
            maybe_remove(a)
          else
            maybe_add(a)
          end
        end
      else
        Rails.logger.warn("#{self.class}: OCR enabled for work #{work.friendlier_id}, but it does not have suitable languages: #{work.language.inspect}")
      end
    else
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
