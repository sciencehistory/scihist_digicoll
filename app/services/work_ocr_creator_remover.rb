# Ensures that a work's OCR data is consistent with its Work#ocr_requested? boolean value
# Ensures that a work's handwriting transcriptiuon data is consistent with its Work#handwriting_transcription_mode? boolean value
#
# Will add OCR data if ocr_requested? but ocr data is missing
# Will remove OCR data is !ocr_requested? but present.
#
# If the gemini_htr_transcripts_feature_flag is on, does the same for Gemini handwriting
# transcriptions, based on Work#handwriting_transcription_mode?. See #process_handwriting_transcription.
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
    process_ocr
    
    if ScihistDigicoll::Env.lookup(:gemini_htr_transcripts_feature_flag)
      process_handwriting_transcription 
    end
  end

  private

  def process_ocr
    if @work.ocr_requested?
      unless AssetOcrCreator.suitable_language?(work)
        Rails.logger.warn("#{self.class}: OCR enabled for work #{work.friendlier_id}, but it does not have suitable languages: #{work.language.inspect}")
        return
      end

      image_assets.each do |a|
        if a.suppress_ocr
          maybe_remove_ocr(a)
        else
          maybe_add_ocr(a)
        end
      end
    elsif @work.text_extraction_mode.blank? # not PDF extraction either
      image_assets.each { |a| maybe_remove_ocr(a) }
    end
  end

  # Unlike OCR, a Gemini transcription costs money, so we only ever request one if this work
  # has never had a request -- not even a failed one. Failed or outdated transcriptions have to
  # be dealt with separately.
  #
  # Transcriptions are removed (and the request forgotten) once the work is no longer in
  # handwriting_transcription mode.
  def process_handwriting_transcription
    if @work.handwriting_transcription_mode?
      return if @work.handwriting_transcription_request.present?

      GeminiHandwritingTranscriptionService.new(work: @work).queue_transcription!
    elsif @work.handwriting_transcription_request.present?
      # Checking for a request first means we don't reindex every other work.
      GeminiHandwritingTranscriptionService.new(work: @work).remove_transcription!
    end
  end

  def maybe_add_ocr(asset)
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
  def maybe_remove_ocr(asset)
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
