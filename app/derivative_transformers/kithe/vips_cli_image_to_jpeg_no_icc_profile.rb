# Creating image derivatives for grayscale images using an sRGB ICC colorspace file
# causes vipsthumbnail to fail with a "Profile incompatible with image" error.
#
# We believe this is resolved by upgrading VIPS to 8.10 from 8.9, but are not 100% sure.
#
# As a temporary measure, we are subclassing
# Kithe::VipsCliImageToJpeg to not use ICC profiles at all, which results in a slightly
# less efficient derivative creation process but does not break with grayscale images.
#
# After we roll back this change, sRGB images created without --eprofile sRGB2014.icc
# will need to have their derivatives recreated.
module Kithe
  class VipsCliImageToJpegNoIccProfile < Kithe::VipsCliImageToJpeg
    private
    def maybe_profile_normalization_args
      return [] unless thumbnail_mode?
      # ["--eprofile", srgb_profile_path, "--delete"]
      ["--delete"]
    end
  end
end