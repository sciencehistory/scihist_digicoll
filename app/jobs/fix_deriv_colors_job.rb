# TEMPORARY job for data migration to re-generate some thumbs and derivatives
# to fix colors
class FixDerivColorsJob < ApplicationJob
  queue_as :special_jobs

  DERIVS = %w{
    thumb_mini
    thumb_mini_2X
    thumb_standard
    thumb_standard_2X
    thumb_large
    thumb_large_2X
  }

  def perform(asset)
    # Make sure DZI deleting happens inline, not in a separate job
    asset.set_promotion_directives(promote: :inline, delete: :inline, create_derivatives: :inline)

    if (thumb_derivs = self.class.needed_derivs(asset)).present?
      asset.create_derivatives(only: thumb_derivs)
    end

    if self.class.needed_dzi?(asset)
      DziFiles.new(asset).create
    end
  end

  private

  # identify derivatives from list of interest that have NOT been created
  # with the proper srgb conversion
  def self.needed_derivs(asset)
    DERIVS.find_all do |deriv_key|
      metadata = asset.file_derivatives[deriv_key.to_sym]&.metadata

      !metadata&.dig("vips_command")&.include?("--export-profile srgb")
    end
  end

  # if DZI has NOT been created with the proper command to convert
  # color profile
  def self.needed_dzi?(asset)
    !asset.dzi_manifest_file&.metadata&.dig("vips_command")&.include?("icc_transform")
  end

end
