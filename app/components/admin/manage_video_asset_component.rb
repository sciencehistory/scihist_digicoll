module Admin
  class ManageVideoAssetComponent < ApplicationComponent
    DEFAULT_VTT_LINK_LABEL = "[WebVTT]"

    attr_reader :asset

    def initialize(asset)
      unless asset.content_type&.start_with?("video/")
        raise ArgumentError.new("Can only be used with video assets, #{asset.friendlier_id} has content_type #{asset.content_type}")
      end

      @asset = asset
    end

    # @returns [False,String] false, or a boolean message on why
    def invalid_for_asr
      if asset.file_derivatives[AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY].blank?
        return "Missing <code>#{AssetUploader::LOFI_OPUS_AUDIO_DERIV_KEY.inspect}</code> derivative".html_safe
      end

      return false
    end

    def asr_webvtt_download_label
      created_at = @asset.file_derivatives[Asset::ASR_WEBVTT_DERIVATIVE_KEY]&.metadata&.dig("created_at")

      return DEFAULT_VTT_LINK_LABEL unless created_at

      I18n.l(DateTime.parse(created_at).localtime, format: :long)
    rescue Date::Error
      return DEFAULT_VTT_LINK_LABEL
    end

    def corrected_webvtt_download_label
      filename = @asset.file_derivatives[Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY]&.metadata&.dig("filename")
      created_at = @asset.file_derivatives[Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY]&.metadata&.dig("created_at")

      return DEFAULT_VTT_LINK_LABEL unless created_at || filename.present?

      "#{I18n.l(DateTime.parse(created_at).localtime, format: :long)} — #{filename}"
    rescue Date::Error
      return DEFAULT_VTT_LINK_LABEL
    end

  end
end
