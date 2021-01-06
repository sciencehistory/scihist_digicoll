module Kithe

  class VipsCliImageToJpegNoProfile < Kithe::VipsCliImageToJpeg
    private
    def maybe_profile_normalization_args
      return [] unless thumbnail_mode?
      ["--delete"]
    end
  end
end