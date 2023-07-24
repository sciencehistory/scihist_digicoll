# Creates a single-page PDF with a single image in it, and nothing else.
#
# Uses prawn, so can handle an image format prawn can handle (NOT jp2).
#
# Takes dpi to make the pdf page the right screen/print/"physical" size, using
# prawn/PDF 72 dpi coordinates.
#
# Returns as a ruby Tempfile, not a permanent file! Assuming you will be uploading
# or combining elsewhere.
class SingleImagePdfCreator
  attr_reader :img_file, :dpi

  # @param img_file [File] image file, at size/resolution you want to embed.
  #   (we could extend to take a string path, since prawn supports those. Maybe
  #   even a URL)
  # @param
  # @param img_height [Integer] height of image you passed in
  # @param dpi [Integer] dpi of file, will be used to size pdf
  def initialize(img_file, img_width:, img_height:, dpi:)
    @img_file = img_file
    @dpi = dpi
  end

  #
  def call
    output_tempfile = Tempfile.new(["scihist_digicoll_single_image_pdf_creator", ".pdf"])

    pdf = Prawn::Document.new(
      margin: 0,
      skip_page_creation: true,
      page_size: [PAGE_WIDTH, PAGE_HEIGHT],
  end

  def pdf_coords_width


end
