module ImageHelper

  # Create an image tag for a thumbnail/derivative image.
  #
  #      thumb_image_tag(asset) # 'standard' thumb size
  #      thumb_image_tag(asset, size: :large) # or :mini
  #
  #      # can add other keyword args that will be passed to Rails image_tag:
  #      thumb_image_tag(asset, class: "foo")
  #
  # We may switch where the image URLs come from (a redirect instead of direct S3?)
  #
  # This maybe would be better in a presenter or something, but for now, rails helpers.
  def thumb_image_tag(asset, size: :standard, **image_tag_options)
    thumb_size = size.to_s
    unless %w{mini large standard}.include?(thumb_size)
      raise ArgumentError, "thumb_size must be mini, large, or standard"
    end

    return nil if asset.nil? # default image instead?

    derivative_key = "thumb_#{size}".to_sym
    derivative_key_2x = "#{derivative_key.to_s}_2X".to_sym

    image_tag asset.derivative_for(derivative_key).url,
      srcset: "#{asset.derivative_for(derivative_key).url} 1x, #{asset.derivative_for(derivative_key_2x).url} 2x",
      **image_tag_options
  end
end
