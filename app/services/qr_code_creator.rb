require 'rqrcode'
require 'chunky_png'

# Generate a QR code PNG for a URL (or any string), optionally with a custom
# icon composited into the center.
#
# The typical way to embed a custom icon in a QR code is weirdly to just add
# a lot of error tolerance and stick it in the middle -- that's what we're doing.
# When an icon is given the QR is encoded at error-correction level :h
# (~30% recovery), which is what keeps it scannable with the center covered.
#
# Keep icon_ratio at or below ~0.22 (22% of width) to stay within that budget.
# Without an icon we use rqrcode's default error-correction level.
#
# We use rqqrcode to encode and render the
# QR matrix, and ChunkyPNG (already a dependency of rqrcode) to scale and
# composite the icon -- which must be a PNG too.
#
# Usage:
#
#     image = QrCodeCreator.new(
#       "https://digital.sciencehistory.org/works/abc123",
#       icon_path: Rails.root.join("app/assets/images/logo.png").to_s
#     ).call
#
#     image.save("out.png")   # => write to disk
#     image.to_blob           # => PNG bytes, eg for send_data
#
class QrCodeCreator
  attr_reader :data, :icon_path, :module_px, :quiet_zone, :icon_ratio, :icon_pad

  # @param data [String] the URL (or other string) to encode
  # @param icon_path [String, nil] path to a PNG icon to composite into the
  #   center. When given, the QR is encoded at error-correction level :h so it
  #   stays scannable with the center covered. When nil (the default), a plain
  #   QR is produced at rqrcode's default error-correction level.
  # @param module_px [Integer] pixel size of each QR "module" (square)
  # @param quiet_zone [Integer] width of the white border, in modules
  # @param icon_ratio [Float] icon width as a fraction of the QR width; keep
  #   <= ~0.22 so the code stays scannable
  # @param icon_pad [Integer] white padding, in pixels, added around the icon
  #   so it reads cleanly against the QR modules
  def initialize(data, icon_path: nil, module_px: 12, quiet_zone: 4, icon_ratio: 0.22, icon_pad: 6)
    @data = data
    @icon_path = icon_path
    @module_px = module_px
    @quiet_zone = quiet_zone
    @icon_ratio = icon_ratio
    @icon_pad = icon_pad
  end

  # @return [ChunkyPNG::Image] the QR code, with the icon composited in the
  #   center if one was given. Call #to_blob for PNG bytes, or #save(path).
  def call
    canvas = generate_qr

    compose_icon!(canvas) if icon_path

    canvas
  end

  private

  # Encode + render the QR matrix to a ChunkyPNG::Image via rqrcode. With an
  # icon we bump to error-correction level :h (~30% recovery) so the center icon
  # doesn't render the code unscannable; without one we use rqrcode's default.
  def generate_qr
    qr = icon_path ? RQRCode::QRCode.new(data, level: :h) : RQRCode::QRCode.new(data)
    qr.as_png(
      module_px_size: module_px,
      border_modules: quiet_zone,
      color: "black",
      fill: "white"
    )
  end

  # Scale the icon to icon_ratio of the QR width (preserving aspect ratio), set
  # it on a solid white pad so it reads cleanly against the QR modules, and
  # composite the result centered onto the QR.
  def compose_icon!(canvas)
    icon = scaled_icon(canvas.width)

    padded = ChunkyPNG::Image.new(icon.width + icon_pad * 2, icon.height + icon_pad * 2, ChunkyPNG::Color::WHITE)
    padded.compose!(icon, icon_pad, icon_pad)

    x = (canvas.width - padded.width) / 2
    y = (canvas.height - padded.height) / 2
    canvas.compose!(padded, x, y)
  end

  # Load the PNG icon and bilinear-resample it to icon_ratio of the QR width,
  # keeping its aspect ratio.
  def scaled_icon(qr_width)
    icon = ChunkyPNG::Image.from_file(icon_path)
    target_w = (qr_width * icon_ratio).round
    target_h = (icon.height * (target_w.to_f / icon.width)).round
    icon.resample_bilinear(target_w, target_h)
  end
end
