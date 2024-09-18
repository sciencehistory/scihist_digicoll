class CreateScaledDownPdfDerivativeJob < ApplicationJob
  def perform(asset)
    unless asset.content_type == "application/pdf"
      raise ArgumentError.new("Requires an asset with content_type application/pdf, not #{asset.content_type.inspect}")
    end

    # will overwrite with new if already existed, which is fine
    asset.create_derivatives(only: [AssetUploader::SCALED_PDF_DERIV_KEY])
  end
end
