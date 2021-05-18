# A sub-class of collection show controller that is specifically for the Oral History
# collection -- it's routed to for that collection in our routes.rb
#
# It lets us override configuration and views.
#
# index view is overridden to use splash page template for splash_page_only?
module CollectionShowControllers
  class OralHistoryCollectionController < CollectionShowController


    # If we have no query params (url after `?`) at all, we just show
    # a splash page, not search results. Even an empty search query is
    # enough to show search results too.
    #
    # We may still be doing a behind-the-scenes search for splash_page_only,
    # to get facet counts to display next to canned queries.
    def splash_page_only?
      request.query_parameters.blank?
    end
    helper_method :splash_page_only?

    # Add and remove some facet fields from inherited default configuration
    configure_blacklight do |config|

      # Remove some facets we don't want, not relevant in this specific collection search
      config.facet_fields.delete("genre_facet")
      config.facet_fields.delete("place_facet")
      config.facet_fields.delete("department_facet")
      config.facet_fields.delete("language_facet")
      config.facet_fields.delete("format_facet") # we use oh_feature_facet instead
      config.facet_fields.delete("creator_facet") # we're going ot use Interviewer specifically instead

      # re-label "date" per stakeholder request
      config.facet_fields["year_facet_isim"].label = "Interview Date"

      # Make "Rights" staff-only, at least fo rnow, with label matching
      config.facet_fields["rights_facet"].tap do |facet_config|
        facet_config.if = :current_user
        facet_config.label = "Rights (Staff-only)"
      end

      # Some facets we don't use generally but we do want to use here.
      config.add_facet_field "interviewer_facet", label: "Interviewer", limit: 5

      config.add_facet_field "oh_institution_facet", label: "Institution", limit: 5
      config.add_facet_field "oh_birth_country_facet", label: "Birth Country", limit: 5

      config.add_facet_field "oh_feature_facet", label: "Features"

      config.add_facet_field "oh_availability_facet", label: "Availability"

      # to change order of keys in hash we basically need to hackily make a new
      # hash.
      key_order = config.facet_fields.keys

      # make interviewer_facet second one
      key_order.insert(1, "interviewer_facet") if key_order.delete("interviewer_facet")

      # and staff-only "visibility" and rights" facets last
      key_order.insert(-1, "published_bsi") if key_order.delete("published_bsi")
      key_order.insert(-1, "rights_facet") if key_order.delete("rights_facet")

      config.facet_fields = config.facet_fields.slice(*key_order)
    end
  end
end
