module ImageHelper

  # Create an image tag for a thumbnail/derivative image.
  #
  #      thumb_image_tag(work.leaf_representative)
  #
  #      thumb_image_tag(asset) # 'standard' thumb size by default
  #      thumb_image_tag(asset, size: :large) # or :mini
  #
  #      # can add other keyword args that will be passed to Rails image_tag:
  #      thumb_image_tag(asset, class: "foo")
  #
  # We may switch where the image URLs come from (a redirect instead of direct S3?)
  #
  # This maybe would be better in a component or something, but for now, rails helpers.
  #
  # TODO: Unify with ThumbComponent?  thumb_image_helper is only used on admin pages,
  # and has the image_missing_text option, ThumbComponent is for public-facing use,
  # but they are very similar.
  def thumb_image_tag(asset, size: :standard, image_missing_text: false, **image_tag_options)
    thumb_size = size.to_s
    unless %w{mini large standard collection_page}.include?(thumb_size)
      raise ArgumentError, "thumb_size must be mini, large, or standard"
    end

    return nil if asset.nil?


    derivative_key = "thumb_#{size}".to_sym
    derivative_url = asset.file_url(derivative_key)
    derivative_key_2x = "#{derivative_key.to_s}_2X".to_sym
    derivative_2x_url = asset.file_url(derivative_key_2x)

    if derivative_url.nil? || derivative_2x_url.nil?
      if image_missing_text
        text = if ! asset.stored?
          "Waiting<br>on ingest…".html_safe
        else
          "derivative<br>not available".html_safe
        end

        return content_tag "div", text, class: "bg-danger text-white derivative-missing-status d-inline-block p-1 small border"
      else
        return nil
      end
    end


    image_tag derivative_url,
      srcset: "#{derivative_url} 1x, #{derivative_2x_url} 2x",
      **image_tag_options
  end

  # if it's been detected as with a white border and is NOT a photo of a museum object,
  # it needs to be displayed with a little border to look right.
  #
  # We like the border blending into bg for physical object photos
  def needs_border?(asset)
    asset.file_metadata[AssetUploader::WHITE_EDGE_DETECT_KEY] && !asset.parent.format.include?("physical_object")
  end
end
