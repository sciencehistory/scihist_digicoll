# A component that displays an image tag, for a thumbnail derivative for a given Kithe::Asset.
#
# The Kithe::Asset provided as an arg will usually be a leaf_representative of a Work or Collection.
#
#     <%= ThumbComponent.new(work.leaf_representative).display %>
#
# In a search results list, leaf_representatives should be eager loaded to avoid n+1 queries in search results display.
#
# * ThumbComponent uses `srcset` tag for high-res images on high-res displays, using our _2x derivatives.
#
# * By default it will display thumb size `standard`, suitable for use in results display, but you
#   can supply any other thumb size we support, eg, :mini, :large, or for collections :collection_page
#
# * Optionally pass `lazy:true` to produce an image tag suitable for lazyloading with lazysizes.js,
#   https://github.com/aFarkas/lazysizes , including a data-aspectratio tag for
#   https://github.com/aFarkas/lazysizes/tree/gh-pages/plugins/aspectratio
#
# ## Placeholders
#
# By default, if suitable derivatives can't be found, it will use our standard placeholder image. Alternate
# placeholders can be specified (such as our collection defaut icon). Note that most of our placeholders
# are svg's, which may not have internal widths specified, so image tags should always be in containers
# with a CSS width/max-width -- and should usually have their own CSS width set to 100% --
# and you should probably manually visually test your layout with placeholders.
#
# ## Note: access control
#
# ThumbComponent does NOT do any access control, it will display whatever you give it, if it can,
# even if not published with no logged in user. Access control should be done by caller.
class ThumbComponent < ApplicationComponent
  attr_accessor :placeholder_img_url, :thumb_size, :asset


  # collection_page for CollectionThumbAssets only, oh well we allow them all for now.
  ALLOWED_THUMB_SIZES = Asset::THUMB_WIDTHS.keys + [:collection_page, :collection_show_page]

  # @param model [Kithe::Asset] the asset whose derivatives we will display
  #
  # @param thumb_size [Symbol] which set of thumb derivatives? :standard, :mini, :large,
  #   :collection_page (for colletions). Both a 1x and 2x derivative must exist. Default
  #   :standard.
  #
  # @param placeholder_img_url [String] url (likely relative path) to a placeholder image
  #   to use if thumb can't be displayed. By default our standard placeholderbox.svg,
  #   but you may want to use the collection default image for collections, etc.
  #
  # @param lazy [Boolean] default false. If true, will use data-src and data-srcset attributes,
  #   and NOT src/srcset direct attributes, for lazy loading with lazysizes.js.
  #
  # @param recent_items [Boolean] The ThumbComponents used in the recent_itmes section of the homepage
  # function slightly differently: they are intended to be visible on screenreaders, so we
  # are allowing an alt text for them.
  #
  # @param aspect_ratio_container [Boolean] Default true, includes a wrapping div used for a "legacy"
  #   method of reserving aspect-ratio space. In the future we may repalce with more recent
  #   less hacky techniques. But setting to 'false' disables this container, for contexts
  #   where it gets in the way and you don't need lazy loading.
  #
  def initialize(asset,
    thumb_size: :standard,
    placeholder_img_url: nil,
    lazy: false,
    alt_text_override: nil,
    aspect_ratio_container: true)

    @asset = asset
    @placeholder_img_url = placeholder_img_url
    @thumb_size = thumb_size.to_sym
    @lazy = lazy
    @alt_text_override = alt_text_override
    @aspect_ratio_container = aspect_ratio_container

    unless ALLOWED_THUMB_SIZES.include? thumb_size
      raise ArgumentError.new("thumb_size must be in #{ALLOWED_THUMB_SIZES}, but was '#{thumb_size}'")
    end
  end

  def call
    thumb_image_tag
  end

  private

  def placeholder_img_url
    # have to apply default value here in lazy memoized, because
    # path helper isn't available in ViewComponent initializer.
    @placeholder_img_url ||= asset_path("placeholderbox.svg")
  end

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
    # If we don't have the thumb URLs we want, use a placeholder -- in
    # the future, we could use media-specific generic icon instead, like
    # an audio/video one or whatever for appropriate type.
    unless asset && res_1x_url && res_2x_url
      return placeholder_image_tag
    end

    img_attributes = {
      alt: "",
      data: {
      }
    }

    if @alt_text_override.present?
      img_attributes[:alt] = @alt_text_override
    elsif asset.alt_text.present?
      img_attributes[:alt] = asset.alt_text
    end

    if lazy?
      # tell lazysizes.js to load with class, and put src/srcset only in
      # data- attributes, so the image will not be loaded immediately, but lazily
      # by lazysizes.js.

      img_attributes[:class] = "lazyload"
      img_attributes[:data].merge!(src_attributes)
    else
      img_attributes.merge!(src_attributes)
    end

    if aspect_ratio_padding_bottom
      # the wrapper div with CSS aspect ratio hack helps reserve space on page before image is loaded.
      # For lazy-loaded images -- but turns out, helpful even for immediate images, which may load slow
      # or at any rate not yet be loaded when page is laid out. Minimize page jumping around.
      content_tag("div", class: "img-aspectratio-container", style: "padding-bottom: #{aspect_ratio_padding_bottom};") do
        tag("img", img_attributes)
      end
    else
      # don't have aspect ratio to reserve space pre-load, just image tag
      tag("img", img_attributes)
    end
  end

  # Used for padding bottom CSS aspect ratio trick. Get height and width from requested thumb.
  def aspect_ratio_padding_bottom
    return false unless @aspect_ratio_container

    thumb = asset&.file("thumb_#{thumb_size}")

    return nil unless thumb && thumb.width && thumb.height

    height_over_width = thumb.height.to_f / thumb.width.to_f

    "#{(height_over_width * 100.0).truncate(1)}%"
  end

  def res_1x_url
    @res_1x_url ||= asset.file_url("thumb_#{thumb_size}")
  end

  def res_2x_url
    @res_2x_url ||= asset.file_url("thumb_#{thumb_size}_2X")
  end

  def src_attributes
    {
       src: res_1x_url,
       srcset: "#{res_1x_url} 1x, #{res_2x_url} 2x"
    }
  end
end
