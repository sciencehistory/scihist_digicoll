# frozen_string_literal: true


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
# * Optionally pass `lazy:true` to use native browser lazy loading
#   https://developer.mozilla.org/en-US/docs/Web/Performance/Lazy_loading
#   https://caniuse.com/loading-lazy-attr
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

  delegate :needs_border?, to: :helpers

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
  def initialize(asset,
    thumb_size: :standard,
    placeholder_img_url: nil,
    lazy: false,
    alt_text_override: nil)

    @asset = asset
    @placeholder_img_url = placeholder_img_url
    @thumb_size = thumb_size.to_sym
    @lazy = lazy
    @alt_text_override = alt_text_override

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
    if asset&.content_type&.start_with?("audio/")
      # use a Audio File icon in SVG. This does mean we'll have repeated svg
      # on a page, some technique to use svg `use`, but not clear how to handle it
      # well while just letting people call ThumbComponent from different places
      helpers.fa_file_audio_class_solid
    else
      tag "img", alt: "", src: placeholder_img_url, width: "100%";
    end
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

    img_attributes.merge!(src_attributes)

    if lazy?
      # native browser lazy loading https://developer.mozilla.org/en-US/docs/Web/Performance/Lazy_loading
      img_attributes.merge!(loading: "lazy")
      # prob doens't matter but doesn't hurt and may help https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/decoding
      img_attributes.merge!(decoding: "async")
    end

    if needs_border?(asset)
      img_attributes[:class] = "bordered"
    end

    img_attributes.merge!(style: aspect_ratio_style_tag)

    tag("img", img_attributes)
  end

  # style tag with aspect-ratio css to reserve proper space on page for lazy loading or not yet loaded images
  def aspect_ratio_style_tag
    # the asset itself could be weird media without height/width itself maybe?  So we look at
    # thumb we're actually displaying for width and height
    thumb = asset&.file("thumb_#{thumb_size}")

    if asset.width && asset.height
      # width / height as string is supported
      return "aspect-ratio: #{thumb.width} / #{thumb.height}"
    elsif lazy?
      Rails.logger.warn("Could not find height and width for aspect-ratio CSS for lazy-loaded image #{asset.friendlier_id}")
      return nil
    end
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
