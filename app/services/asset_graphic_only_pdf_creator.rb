# Given an original TIFF, creates a one-page PDF containing that graphic,
# embedded as a *JP2*.
#
# Calls out to various command line tools:
# * vipsthumbnail to resize TIFF as a JP2
# * mediainfo to read TIFF dpi if needed
# * img2pdf (python) to embed jp2 in PDF
#
class AssetGraphicOnlyPdfCreator
  # one way to get dpi from a TIFF, there are others!
  class_attribute :mediainfo_command, default: "mediainfo"
  class_attribute :vipsthumbnail_command, default: "vipsthumbnail"

  # A python pip package, that we still haven't totally figured out how we're
  # going to get installed.
  class_attribute :img2pdf_convert_command, default: "img2pdf"


  # Will resize output to this DPI, based on known input DPI
  DEFAULT_TARGET_DPI = 150

  # a low-sounding 40 looks good to us for vips jp2 compression value,
  # we don't see any artifacts
  DEFAULT_COMPRESSION_Q = 40

  # If we can't extract dpi, we'll assume this
  GUESS_ASSUME_SOURCE_DPI = 400

  attr_reader :original_file, :asset, :compression_quality, :target_dpi

  # @param asset [Asset] Asset with a TIFF original
  #
  # @param original_file [File] optional, if you already have the asset original file downloaded,
  #                             pass it in so we don't need to download it again.
  #
  # @param compression_quality [Integer] 'Q' param to vips for lossy compression quality
  #                             https://www.libvips.org/2021/06/04/What's-new-in-8.11.html
  #
  # @param target_dpi [Integer] target DPI of output image
  def initialize(asset,
    original_file: nil,
    target_dpi: DEFAULT_TARGET_DPI,
    compression_quality: DEFAULT_COMPRESSION_Q)

    @asset = asset
    @original_file = original_file
    @target_dpi = target_dpi
    @compression_quality = compression_quality
  end

  # @returns [Tempfile] a PDF
  def create
    jp2_temp_file = create_sized_jp2

    pdf_from_graphic(jp2_temp_file)
  ensure
    jp2_temp_file.unlink if jp2_temp_file
  end

  # @return Tempfile
  #
  # WARNING: This jp2 IS going to have missing dpi in it's metadata, we haven't
  #          figured out to write that with vips yet
  def create_sized_jp2(jp2_quality: 40)
    # use passed-in original file if we have it, otherwise download via shrine
    downloaded_new_copy = false
    temp_orig  = original_file
    unless temp_orig
      downloaded_new_copy = true
      temp_orig = asset.file.download
    end

    orig_width = asset.width
    orig_dpi   = get_tiff_dpi(temp_orig.path)

    # what to resize x width to get from original dpi to target dpi?
    target_width = (orig_width.to_f * (target_dpi.to_f / orig_dpi.to_f)).round

    output_jp2_tempfile = Tempfile.new(["scihist_digicoll_asset_graphic_only_pdf_creator", ".jp2"])

    # subsample-mode=off is to work around a bug in OpenJPEG -- more recent
    # versions of vips always turn subsample mode off, but it does need to be off
    # to avoid color corruption depending on image size:
    # https://github.com/libvips/libvips/issues/2965

    # export-profile srgb is to work around vips/OpenJPEG inability to embed
    # ICC profile or colorspace metadata, we NEED to convert to sRGB bytes
    # to avoid color shifts.
    # https://github.com/libvips/libvips/discussions/3428#discussioncomment-6383390

    tty_command.run(
      vipsthumbnail_command,
      temp_orig.path,
      "--size","#{target_width}x65500",
      "--export-profile", "srgb",
      "-o", "#{output_jp2_tempfile.path}[Q=#{compression_quality},subsample-mode=off]"
    )

    # note dpi metadata on output jp2 is always 72. :(

    output_jp2_tempfile
  ensure
    temp_orig.close! if downloaded_new_copy && temp_orig
  end

  # Use img2pdf python utility to embed an image in a PDF.
  #
  # Set the DPI properly on PDF too.
  #
  # @param graphic_temp_file [Tempfile]
  # @param dpi [Integer] known dpi of jp2_temp_file
  #
  # @return [Tempfile] a PDF that just has the graphic embedded, with proper target_dpi set
  #
  # Note img2pdf can't handle input with an alpha channel (eg for transparency), if you
  # somehow wind up with one, you'll currently get a TTY::Command::ExitError raised:
  # `This function must not be called on images with alpha`
  def pdf_from_graphic(graphic_temp_file)
    output_pdf_tempfile = Tempfile.new(["scihist_digicoll_asset_pdf_creator", ".pdf"])

    tty_command.run(
      img2pdf_convert_command,
      graphic_temp_file.path,
      "--imgsize", "#{target_dpi} dpi",
      "-o",output_pdf_tempfile.path
    )

    output_pdf_tempfile
  end

  # in future we may store dpi as metadata on asset, so we don't need to look it up
  # from a downloaded copy.
  #
  # Try to use mediainfo to extract dpi from TIFF; if we can't find it,
  # assume a default source DPI.
  #
  # @returns [Float] dpi
  def get_tiff_dpi(file_path)
    out, err = tty_command.run(
      mediainfo_command,
      "--Inform=Image;\%Density_X\% \%Density_Unit\%",
      file_path
    )

    if out =~ /\A(\d+(\.?\d+)?) dpi/
      return $1.to_f
    else
      Rails.logger.warn("#{self.class}: Could not find dpi for Asset #{asset.friendlier_id}, assuming #{GUESS_ASSUME_SOURCE_DPI}")
      return GUESS_ASSUME_SOURCE_DPI
    end
  end

  private

  def tty_command
    @tty_comand ||= TTY::Command.new(printer: :null)
  end
end
