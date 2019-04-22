require 'tempfile'
require 'tty/command'

module Kithe
  # Use the [vips](https://jcupitt.github.io/libvips/) command-line utility (via shell-out)
  # to transform any image type to a JPG, with a specified maximum width (keeping aspect ratio).
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

  class Kithe::VipsCliPdfToJpeg
    class_attribute :srgb_profile_path, default: Kithe::Engine.root.join("lib", "vendor", "icc", "sRGB2014.icc").to_s
    class_attribute :vips_thumbnail_command, default: "vipsthumbnail"
    class_attribute :vips_command, default: "vips"
    class_attribute :vips_header_command, default: "vipsheader"

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
    def thumbnail(width, input, output)
      profile_normalization_args=["--eprofile", srgb_profile_path, "--delete"]
      vips_jpg_params="[Q=#{@jpeg_q },interlace,optimize_coding,strip]"
      args = if width
        # Due to bug in vips, we need to provide a height constraint, we make
        # really huge one million pixels so it should not come into play, and
        # we're constraining proportionally by width.
        # https://github.com/jcupitt/libvips/issues/781
        [
          vips_thumbnail_command,
          input.path,
          *profile_normalization_args,
          "--size", "#{width}x1000000",
          "-o", "#{output.path}#{vips_jpg_params}"
        ]
      else
        [ vips_command, "copy",
          input.path,
          *profile_normalization_args,
          "#{output.path}#{vips_jpg_params}"
        ]
      end
      @cmd.run(*args)
    end

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
      @cmd.run(*args)
    end

    # Add a border to the thumbnail.
    # The resulting file is taller and wider by @border_pixels * 2
    def add_border(initial_width, input, output)
      border_color = "0, 0, 0" # black until further notice
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
      @cmd.run(*args)
    end

    def image_height(image)
      args = [vips_header_command, '-f', 'Ysize', image.path]
      @cmd.run(*args).out.to_i
    end
  end
end
