# Allows us to customize various aspects of the date field (year_facet_isim) facet.
class DateFacetItemPresenter < BlacklightRangeLimit::FacetItemPresenter

  # Look up the label for the facet for items missing a date in blacklight.en.yml .
  def label
    if value == {:missing=>true}
      # The path to the label is taken from
      #   https://github.com/projectblacklight/blacklight/blob/457f89f3dba758c0e642e881724cd818c1cc5f9e/lib/blacklight/solr/response/facets.rb#L199
      I18n.t(:"blacklight.search.fields.facet.missing.#{@facet_config.field}", default: super)
    else
      super
    end
  end

end
