require 'tempfile'
require 'tty/command'

module Kithe
  # Use the [vips](https://jcupitt.github.io/libvips/) command-line utility (via shell-out)
  # to transform any image type to a JPG, with a specified maximum width (keeping aspect ratio).
  #
  # Requires vips command line utilities `vips` and `vipsthumbnail` and to be installed on your system,
  # eg `brew install vips`, or apt package `vips-tools`.
  #
  # If thumbnail_mode:true is given, we ALSO apply some additional best practices
  # for minimizing size when used as an image _in a browser_, such as removing
  # color profile information. See eg:
  #  * https://developers.google.com/speed/docs/insights/OptimizeImages
  #  * http://libvips.blogspot.com/2013/11/tips-and-tricks-for-vipsthumbnail.html
  #  * https://github.com/jcupitt/libvips/issues/775
  #
  # It takes an open `File` object in, and returns an open TempFile object. It is
  # built for use with kithe derivatives transformations, eg:
  #
  #     class Asset < KitheAsset
  #       define_derivative(thumb) do |original_file|
  #         Kithe::VipsCliImageToJpeg.new(max_width: 100, thumbnail_mode: true).call(original_file)
  #       end
  #     end
  #
  # We use the vips CLI because we know how, and it means we can avoid worrying
  # about ruby memory leaks or the GIL. An alternative that uses vips ruby bindings
  # would also be possible, and might work well, but this is what for us is tried
  # and true.
  class Kithe::VipsCliPdfToJpeg
    class_attribute :srgb_profile_path, default: Kithe::Engine.root.join("lib", "vendor", "icc", "sRGB2014.icc").to_s
    class_attribute :vips_thumbnail_command, default: "vipsthumbnail"
    class_attribute :vips_command, default: "vips"
    class_attribute :vips_header_command, default: "vipsheader"

    attr_reader :max_width, :jpeg_q

    def initialize(max_width:nil, jpeg_q: 98, thumbnail_mode: false)
      @max_width = max_width
      @jpeg_q = jpeg_q
      @thumbnail_mode = !!thumbnail_mode
      @border_width = 1
      @width_minus_borders = @max_width - (2 * @border_width)
      @cmd = TTY::Command.new(printer: :null)

      if thumbnail_mode && max_width.nil?
        # https://github.com/libvips/libvips/issues/1179
        raise ArgumentError.new("thumbnail_mode currently requires a non-nil max_width")
      end
    end

    # Will raise TTY::Command::ExitError if the external Vips command returns non-null.
    def call(original)
      files = (0..2).map {|x| Tempfile.new(["kithe_vips_pdf", ".jpg"])}
      thumbnail(
        @width_minus_borders,
        original, files[0]
      )
      sharpen(
        @width_minus_borders,
        files[0], files[1]
      )
      add_border(
        @width_minus_borders, image_height(files[1]),
        files[1], files[2]
      )
      files[2]
    end

    private

    def thumbnail_mode?
      @thumbnail_mode
    end

    # Only if we're in thumbnail_mode mode, normalize to rRGB profile, and then strip
    # embedded profile info for a smaller size, since browsers assume sRGB
    def maybe_profile_normalization_args
      return [] unless thumbnail_mode?
      ["--eprofile", srgb_profile_path, "--delete"]
    end

    # Params to add on to end of JPG output path, as in:
    # `vips convert ... -o something.jpg[Q=85]`
    #
    # If we are in thumbnail mode, we strip all profile information for
    # smaller files.
    #
    # Either way we create an interlaced JPG and optimize coding for smaller
    # file size.
    #
    # @returns [String]
    def vips_jpg_params
      if thumbnail_mode?
        "[Q=#{@jpeg_q },interlace,optimize_coding,strip]"
      else
        # could be higher Q for downloads if we want, but we don't right now
        # We do avoid striping metadata, no 'strip' directive.
        "[Q=#{@jpeg_q },interlace,optimize_coding]"
      end
    end

    def thumbnail(width, input, output)
      args = if width
        # Due to bug in vips, we need to provide a height constraint, we make
        # really huge one million pixels so it should not come into play, and
        # we're constraining proportionally by width.
        # https://github.com/jcupitt/libvips/issues/781
        [
          vips_thumbnail_command,
          input.path,
          *maybe_profile_normalization_args,
          "--size", "#{width}x1000000",
          "-o", "#{output.path}#{vips_jpg_params}"
        ]
      else
        [ vips_command, "copy",
          input.path,
          *maybe_profile_normalization_args,
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

    def add_border(old_width, old_height, input, output)
      border_color = "5, 9, 57" # #050939
      args = [vips_command,
       'embed',
        input.path,
        output.path,
        @border_width,
        @border_width,
        old_width + @border_width * 2,
        old_height + @border_width * 2,
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
