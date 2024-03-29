# Rails helper methods for linking to searches and dealing with searches
module SearchHelper

  # Return a Hash of parameters for url_for, that will result in a search a particular facet
  # and value. Used for links on our display of metadata values, that should link to searches.
  #
  # A bit suprisingly hard to do this with built-in Blacklight API, and the built-in Blacklight
  # API that is there does _not_ raise if you try to use a facet field key that is not defined, and
  # we would like to, so do that extra.
  #
  def search_on_facet_path(facet_field, facet_value)
    unless CatalogController.blacklight_config.facet_fields[facet_field.to_s]
      raise ArgumentError.new("No facet field defined for #{facet_field.inspect}. Defined fields are #{CatalogController.blacklight_config.facet_fields.keys.inspect}")
    end

    # Originally tried to use existing Blacklight logic to actually create the `f: { facet_name: [value]}`
    # query param, in case Blacklight does edge case things depending on configuration or whatever,
    # and for DRY.
    #
    # But couldn't figure out how to do it in a way that didn't keep breaking in subsequent BL versions,
    # we just hard-code assumed params we want in URL.

    search_catalog_path(f: { facet_field => [facet_value] })
  end
end
