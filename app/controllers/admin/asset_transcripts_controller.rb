class Admin::AssetTranscriptsController < AdminController
  before_action :set_asset

  def set_audio_asr_enabled
    @asset.update!(audio_asr_enabled: params[:asset][:audio_asr_enabled])

    # If we don't have an ASR, and we just enabled it, then queue a job
    # to create it.
    if !@asset.asr_webvtt? && @asset.audio_asr_enabled_previous_change&.last
      OpenaiAudioTranscribeJob.perform_later(@asset)
    end

    redirect_to admin_asset_path(@asset, anchor: "video_transcription")
  end

  def upload_corrected_vtt

    @asset.file_attacher.add_persisted_derivatives({
       Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY =>
        params[:asset_derivative][Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY]
    })

    redirect_to admin_asset_path(@asset, anchor: "video_transcription")
  end

  def delete_transcript
    unless params[:derivative_key].to_sym.in?([Asset::ASR_WEBVTT_DERIVATIVE_KEY, Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY])
      raise ArgumentError.new("param derivative_key needs to be #{Asset::ASR_WEBVTT_DERIVATIVE_KEY} or #{Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY}, not `#{params[:derivative_key]}`")
    end

    @asset.remove_derivatives(params[:derivative_key].to_sym)

    redirect_to admin_asset_path(@asset, anchor: "video_transcription")
  end

  private

  def set_asset
    @asset = Asset.find_by_friendlier_id(params[:id])
  end
end
