require 'tempfile'
require 'tty/command'

module Kithe
  # Use the [vips](https://jcupitt.github.io/libvips/) command-line utility (via shell-out)
  # to transform the first page of a PDF to a jpeg, with a specified maximum width (keeping aspect ratio).
  #
  # Requires vips command line utilities `vips` and `vipsthumbnail` and to be installed on your system,
  # eg `brew install vips`, or apt package `vips-tools`.
  #
  # We ALSO apply some additional best practices
  # for minimizing size when used as an image _in a browser_, such as removing
  # color profile information. See eg:
  #  * https://developers.google.com/speed/docs/insights/OptimizeImages
  #  * http://libvips.blogspot.com/2013/11/tips-and-tricks-for-vipsthumbnail.html
  #  * https://github.com/jcupitt/libvips/issues/775

  # PDF thumbnails are sharpened, unlike regular images in our collection, as they tend to
  # contain mostly text. Also, since the first page of our oral history PDFs are mostly white space, adding
  # a border makes it easier to see what they are against a white background.

  # The recipe is thus:
  # 1) Create a thumbnail of the first page of the PDF. Make it slightly narrower than the final product.
  # 2) Sharpen the thumbnail
  # 3) Add a border around the image, such that the resulting thumbnail is @max_width pixels wide.

  class Kithe::VipsCliPdfToJpeg
    class_attribute :srgb_profile_path, default: Kithe::Engine.root.join("lib", "vendor", "icc", "sRGB2014.icc").to_s
    class_attribute :vips_thumbnail_command, default: "vipsthumbnail"
    class_attribute :vips_command, default: "vips"
    class_attribute :vips_header_command, default: "vipsheader"
    class_attribute :pdfinfo_command, default: "pdfinfo"

    # libvips default render resolution for pdfload, used as a ceiling so we never
    # try to render at higher-than-native resolution.
    DEFAULT_PDF_DPI = 72.0

    attr_reader :max_width, :jpeg_q

    def initialize(max_width:nil, jpeg_q: 98)
      @max_width = max_width
      @jpeg_q = jpeg_q
      @border_pixels = 1
      @cmd = TTY::Command.new(printer: :null)

      if max_width.nil?
        # https://github.com/libvips/libvips/issues/1179
        raise ArgumentError.new("thumbnail_mode currently requires a non-nil max_width")
      end
    end

    # Will raise TTY::Command::ExitError if the external Vips command returns non-null.
    def call(original)
      # Create three temp files
      thumbnail, sharpened_thumb, with_borders_thumb = 3.times.
        map { Tempfile.new(["kithe_vips_pdf", ".jpg"]) }
      # Make a slightly thinner thumbnail to
      # accomodate the border we're adding at the end.
      width_minus_borders = @max_width - (2 * @border_pixels)
      # Create and sharpen a thumbnail, then add a black border to it.
      thumbnail( width_minus_borders, original,        thumbnail)
      sharpen(   width_minus_borders, thumbnail,       sharpened_thumb)
      add_border(width_minus_borders, sharpened_thumb, with_borders_thumb)
      # The width of the thumbnail, including the border,
      # is now exactly @max_width.
      thumbnail.unlink
      sharpened_thumb.unlink
      with_borders_thumb
    end

    private

    # Creates a thumbnail of the specified width.
    # If you want to add a border later on, you want to pass in a
    # slightly smaller width to accomodate that.
    #
    # Renders the PDF's first page ourselves via the explicit `pdfload` operation,
    # rather than letting `vipsthumbnail` do its own format-sniffing load, so a
    # malicious file can't get mis-detected as some other, more dangerous, loader.
    # https://www.libvips.org/2022/05/28/What's-new-in-8.13.html
    #
    # Once we've rendered a raster ourselves, it's safe to use vipsthumbnail on
    # the file WE produced.
    def thumbnail(width, input, output)
      vips_jpg_params="[Q=#{@jpeg_q },interlace,optimize_coding,strip]"

      rendered_image = Tempfile.new(["kithe_vips_pdf_page", ".tif"])

      dpi = estimated_dpi_for_width(input.path, width)
      @cmd.run(vips_command, "pdfload", input.path, rendered_image.path, "--page", "0", "--dpi", dpi.to_s)

      @cmd.run(
        vips_thumbnail_command, rendered_image.path,
        "--eprofile", srgb_profile_path, "--delete", # profile normalization args
        "--size", "#{width}x1000000",
        "-o", "#{output.path}#{vips_jpg_params}",
        env: { "VIPS_BLOCK_UNTRUSTED" => "1" }
      )
    ensure
      rendered_image.close! if rendered_image
    end

    # Uses `pdfinfo` to estimate dpi of PDF, for more efficiently creating thumbnail.
    def estimated_dpi_for_width(pdf_path, target_width)
      out, _err = @cmd.run(pdfinfo_command, pdf_path)

      if out =~ /^Page size:\s*([\d.]+)\s*x\s*[\d.]+\s*pts/ && $1.to_f > 0
        native_width_points = $1.to_f
        # native_width_points is exactly the page's pixel width at the default 72 DPI,
        # so this ratio gives us the DPI to hit target_width. Never render above the
        # default DPI (i.e. don't try to upscale beyond native resolution).
        (DEFAULT_PDF_DPI * (target_width.to_f / native_width_points)).clamp(1.0, DEFAULT_PDF_DPI)
      else
        DEFAULT_PDF_DPI
      end
    end

    # Sharpen a thumbnail.
    # A full description of the paramaters below can be found at
    # https://jcupitt.github.io/libvips/API/8.6/libvips-convolution.html#vips-sharpen
    def sharpen(width, input, output)
      args = [
        vips_command,  "sharpen",
         input.path,
         output.path,
        "--sigma",     ((width > 150) ? 3 : 1).to_s,
        "--x1",        "2"   ,
        "--y2",        "10"  , # (don't brighten by more than 10 L*)
        "--y3",        "10"  , # (can darken by up to 20 L*)
        "--m1",        "0"   , # (no sharpening in flat areas)
        "--m2",        "3"   , # (some sharpening in jaggy areas)
      ]
      @cmd.run(*args, env: { "VIPS_BLOCK_UNTRUSTED" => "1" })
    end

    # Add a rectangular border (@border_pixels wide) around the thumbnail.
    # The image returned will be taller and wider by @border_pixels * 2.
    # Note: unlike the other methods in this class, this one makes two calls
    # to the shell.
    def add_border(initial_width, input, output)
      border_color = "0, 0, 0" # black until further notice
      # Note: calling image_height below
      # results in a separate shell call.
      initial_height = image_height(input)
      new_width =  initial_width  + @border_pixels * 2
      new_height = initial_height + @border_pixels * 2
      args = [vips_command,
       'embed',
        input.path, output.path,
        @border_pixels, @border_pixels,
        new_width, new_height,
        '--extend', 'background',
        '--background', border_color
      ]
      @cmd.run(*args, env: { "VIPS_BLOCK_UNTRUSTED" => "1" })
    end

    # Return the height of an image in pixels.
    def image_height(image)
      args = [vips_header_command, '-f', 'Ysize', image.path]
      @cmd.run(*args, env: { "VIPS_BLOCK_UNTRUSTED" => "1" }).out.to_i
    end
  end
end
