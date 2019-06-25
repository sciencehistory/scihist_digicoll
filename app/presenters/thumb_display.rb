# A ViewModel presenter that displays an image for a given Kithe::Asset.
#
# The Kithe::Asset provided as an arg will usually be a leaf_representative of a Work or Collection.
#
#     <%= ThumbDisplay.new(work.leaf_representative).display %>
#
# In a search results list, leaf_representatives should be eager loaded to avoid n+1 queries in search results display.
#
# By default, it will display thumb size :standard, suitable for use in results display, but you can
# supply another thumb size initializer arg.
#
# By default, it will use our standard placeholder image if no derivaties are availalble, but you can
# supply an alternate placeholder image path in initializer arg.
class ThumbDisplay < ViewModel
  valid_model_type_names "Kithe::Asset", "NilClass"

  attr_accessor :placeholder_img_url, :thumb_size

  # collection_page for CollectionThumbAssets only, oh well we allow them all for now.
  ALLOWED_THUMB_SIZES = Asset::THUMB_WIDTHS.keys + [:collection_page]

  def initialize(model,
    placeholder_img_url: asset_path("placeholderbox.svg"),
    thumb_size: :standard)

    @placeholder_img_url = placeholder_img_url
    @thumb_size = thumb_size.to_sym

    unless ALLOWED_THUMB_SIZES.include? thumb_size
      raise ArgumentError.new("thumb_size must be in #{ALLOWED_THUMB_SIZES}, but was '#{thumb_size}'")
    end

    super(model)
  end

  def display
    # for non-pdf/image assets, we currently just return a placeholder. We could in future
    # return a default audio/video icon thumb or something. At present we don't intend to use
    # a/v as representative images.
    if model.nil? || model.content_type.nil? || !(model.content_type == "application/pdf" || model.content_type.start_with?("image/"))
      return placeholder_image
    end

    multi_res_standard_thumb
  end

  private

  def placeholder_image
    tag "img", alt: "", src: placeholder_img_url, width: "100%";
  end

  # "standard" size thumb, providing srcset wtih double-res image for better
  # display on high-res screens
  #
  # alt is "" intentionally, because screen-readers should ignore this thumb,
  # search results are perfectly usable without it and there's nothing we
  # can say about it except "a thumbnail" or something, not useful.
  #
  # If necessary derivatives aren't there, will return placeholder.
  #
  # Currently uses direct-to-S3 URLs, provided by shrine. Maybe signed
  # URLs depending on shrine settings (beware of performance issues
  # if they are signed?)
  def multi_res_standard_thumb
    res_1x_url = model.derivative_for("thumb_#{thumb_size}").try(:url)
    res_2x_url = model.derivative_for("thumb_#{thumb_size}_2X").try(:url)

    unless res_1x_url && res_2x_url
      return placeholder_image
    end

    tag("img",
         alt: "",
         src: res_1x_url,
         srcset: "#{res_1x_url} 1x, #{res_2x_url} 2x"
    )
  end
end
