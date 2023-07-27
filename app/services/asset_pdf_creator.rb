# Creates a single-page PDF from a single asset.
#
# Will include text layer for OCR-requested Assets that have the textonly_pdf derivative present.
#
# Uses a BUNCH of command-line shell-outs.
#
class AssetPdfCreator
  # one way to get dpi from a TIFF, there are others!
  class_attribute :mediainfo_command, default: "mediainfo"
  class_attribute :vipsthumbnail_command, default: "vipsthumbnail"

  # A python pip package, that we still haven't totally figured out how we're
  # going to get installed.
  class_attribute :img2pdf_convert_command, default: "img2pdf"
  class_attribute :qpdf_command, default: "qpdf"

  DEFAULT_TARGET_DPI = 150
  GUESS_ASSUME_SOURCE_DPI = 400 # what we usually use for 2D photos I think

  attr_reader :asset, :target_dpi

  def initialize(asset, target_dpi: DEFAULT_TARGET_DPI)
    @asset = asset
    @target_dpi = target_dpi
  end

  def create
    jp2_temp_file = create_sized_jp2

    graphical_pdf = pdf_from_graphic(jp2_temp_file)
    textonly_pdf_file = nil
byebug
    # If we have a textonly_pdf, we got to combine them. Else this is it.
    if asset.file_derivatives[:textonly_pdf].present?
      textonly_pdf_file = asset.file_derivatives[:textonly_pdf].download

      combined_pdf = combine_pdfs(textonly_pdf_file: textonly_pdf_file, graphic_pdf_file: graphical_pdf)
      graphical_pdf.unlink

      combined_pdf
    else
      graphical_pdf
    end
  ensure
    jp2_temp_file.unlink if jp2_temp_file
    textonly_pdf_file.unlink if textonly_pdf_file
  end


  # @param jp2_quality [Integer] a 1-99 quality indicator that vips will use for
  #   lossy compression in jp2. https://www.libvips.org/2021/06/04/What's-new-in-8.11.html
  #
  #   Default jp2_quality is as low as we think we can go without visible artifacts --
  #   it's a pretty low number. started at 38, but maybe 40 better to be safe.
  #
  # @return Tempfile
  #
  # WARNING: This jp2 IS going to have missing dpi in it's metadata, we haven't
  #          figured out to write that with vips yet
  def create_sized_jp2(jp2_quality: 40)
    temp_orig = asset.file.download

    orig_width = asset.width
    orig_dpi   = get_tiff_dpi(temp_orig.path)

    # what to resize x width to get from original dpi to target dpi?
    target_width = (orig_width.to_f * (target_dpi.to_f / orig_dpi.to_f)).round

    output_jp2_tempfile = Tempfile.new(["scihist_digicoll_asset_pdf_creator", ".jp2"])

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
      "-o", "#{output_jp2_tempfile.path}[Q=#{jp2_quality},subsample-mode=off]"
    )

    # note dpi metadata on output jp2 is always 72. :(

    output_jp2_tempfile
  end

  # Use ImageMagick to embed an image in a PDF. ImageMagick definitely ain't super fast.
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
      return GUESS_ASSUME_SOURCE_DPI
    end
  end

  # Returns a combined PDF with graphical PDF and text-only PDF.
  #
  # WARNING:  the textonly pdf NEEDS to be same size or "bigger", and then
  #           qpdf will scale it down to fit and match. If textonly pdf is SMALLER,
  #           it will get overlaid as a smaller inset and not line up.
  #
  def combine_pdfs(textonly_pdf_file:, graphic_pdf_file:)
    combined_temp_file = Tempfile.new(["scihist_digicoll_asset_pdf_creator", ".pdf"])

    tty_command.run(
      qpdf_command,
      graphic_pdf_file.path,
      "--underlay", textonly_pdf_file.path,
      "--",
      combined_temp_file.path
    )

    combined_temp_file
  end

  private

  def tty_command
    @tty_comand ||= TTY::Command.new(printer: :null)
  end


end
