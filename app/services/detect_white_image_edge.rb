# Use ImageMagick to see if an image has a white border -- because then we might want to give
# it a border when displaying over a white backgrond!
#
# Our actual scans usually don't, even of white pages, because some of the table
# the book lay on is included.
#
# But born-digital pages often will.
#
# Examples show this might take 1-4 seconds for our really big TIFFs on relatively
# slow heroku, not too bad.
#
class DetectWhiteImageEdge
  class_attribute :magick_command, default: "convert"

  def initialize(color: "white", fuzz: "5%")
    @color = color
    @fuzz = fuzz

    @cmd = TTY::Command.new(printer: :null)
  end

  # @returns [Boolean] true if white edges detected!
  def call(file_path)
    # https://usage.imagemagick.org/crop/#trim_color
    args = [
      magick_command,
      file_path,
      "-bordercolor", @color,
      "-border", "1x1",
      "-fuzz", @fuzz,
      "-trim",
      "-format", "%O", # `page (canvas) offset ( = %X%Y )`
      "info:" # don't write out an image, just write out info on the image, perfect! with format being what info in what format
    ]

    output = @cmd.run(*args).out

    if output == "-1-1"
      # special sign it was totally white image that was totally trimmed to oblivion
      return true
    end

    output =~ /\+(\d+)\+(\d+)/
    x_offset, y_offset = $1.to_i, $2.to_i

    return x_offset > 1 && y_offset > 1
  end
end
