# Creates a single-page PDF from a single asset.
#
# Will include text layer for OCR-requested Assets that have the textonly_pdf derivative present.
#
# Uses a BUNCH of command-line shell-outs.
#
# NOTE: It returns ruby Tempfile objects, assuming you will be uploading to S3 -- the tempfiles
#       themselves will end up deleted by ruby (although it's good practice to clean them up
#       manually) you can't count on them staying around!
#
class AssetPdfCreator
  class_attribute :qpdf_command, default: "qpdf"

  attr_reader :asset

  # @param asset [Asset]
  def initialize(asset)
    @asset = asset
  end

  # @return Tempfile
  def create
    if asset.file_derivatives[:graphiconly_pdf].present?
      graphical_pdf = asset.file_derivatives[:graphiconly_pdf].download
    else
      graphical_pdf = AssetGraphicOnlyPdfCreator.new(asset).create
    end

    textonly_pdf_file = nil
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
    textonly_pdf_file.unlink if textonly_pdf_file
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
