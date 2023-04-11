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
  def initialize(work, callback: nil, overwrite_existing_ocr: false, do_now: false)
    @work = work
    @overwrite_existing_ocr = overwrite_existing_ocr
    @do_now = do_now
    @this_is_dev = (ScihistDigicoll::Env.lookup(:service_level)  == 'development')
  end

  def process
    if @work.ocr_requested
      image_assets_we_can_download.each { |a| maybe_add(a) }
    else
      image_assets_we_can_download.each { |a| a.update!(hocr: nil) }
    end
  end

  private

  def maybe_add(asset)
    # tolerate missing files in dev; fail immediately otherwise.
    return if @this_is_dev && !asset.file.exist?
    add_ocr(asset) if @overwrite_existing_ocr || asset.hocr.blank?
  end


  def add_ocr(asset)
    @do_now ? AssetHocrCreator.new(asset).call : CreateAssetHocrJob.perform_later(asset) 
  end

  def image_assets_we_can_download
    @work.
      members.
      where(type: 'Asset').
      order(:position).
      select { |m| m.content_type.start_with?("image/") }
  end
end