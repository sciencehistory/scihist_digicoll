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
    thumb_size: :standard,
    lazy: false)

    @placeholder_img_url = placeholder_img_url
    @thumb_size = thumb_size.to_sym
    @lazy = lazy

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
      return placeholder_image_tag
    end

    thumb_image_tag
  end

  private

  def lazy?
    !!@lazy
  end

  def placeholder_image_tag
    tag "img", alt: "", src: placeholder_img_url, width: "100%";
  end

  # A thumb 'img' tag that provides srcset wtih double-res image for better
  # display on high-res screens.
  #
  # Takes the thumb size arg, and assumes derivs are available named "thumb_#{size}"
  # and "thumb_#{size}_2X"
  #
  # If necessary derivatives aren't there, will return placeholder -- right now
  # it needs 1x and 2x derivatives.
  #
  # alt is "" intentionally, because screen-readers should ignore this thumb,
  # search results are perfectly usable without it and there's nothing we
  # can say about it except "a thumbnail" or something, not useful.
  #
  # Currently uses direct-to-S3 URLs, provided by shrine. Maybe signed
  # URLs depending on shrine settings (beware of performance issues
  # if they are signed?)
  def thumb_image_tag
    unless res_1x_url && res_2x_url
      return placeholder_image_tag
    end

    img_attributes = {
      alt: "",
      data: {
        aspectratio: aspect_ratio
      }
    }

    if lazy?
      # tell lazysizes.js to load with class, and put src/srcset only in
      # data- attributes, so the image will not be loaded immediately, but lazily
      # by lazysizes.js.
      img_attributes[:class] = "lazyload"
      img_attributes[:data].merge!(src_attributes)
    else
      img_attributes.merge!(src_attributes)
    end

    tag("img", img_attributes)
  end

  # used for lazysizes-aspectratio
  # https://github.com/aFarkas/lazysizes/tree/gh-pages/plugins/aspectratio
  def aspect_ratio
    if model && model.width && model.height
      "#{model.width}/#{model.height}"
    else
      nil
    end
  end

  def res_1x_url
    @res_1x_url ||= model.derivative_for("thumb_#{thumb_size}").try(:url)
  end

  def res_2x_url
    @res_2x_url ||= model.derivative_for("thumb_#{thumb_size}_2X").try(:url)
  end

  def src_attributes
    {
       src: res_1x_url,
       srcset: "#{res_1x_url} 1x, #{res_2x_url} 2x" if
    }
  end
end
