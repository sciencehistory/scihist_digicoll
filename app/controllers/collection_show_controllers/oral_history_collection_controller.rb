# A sub-class of collection show controller that is specifically for the Oral History
# collection -- it's routed to for that collection in our routes.rb
#
# It lets us override configuration and views.
module CollectionShowControllers
  class OralHistoryCollectionController < CollectionShowController

    # Add and remove some facet fields from inherited default configuration
    configure_blacklight do |config|

      # Remove some facets we don't want, not relevant in this specific collection search
      config.facet_fields.delete("genre_facet")
      config.facet_fields.delete("place_facet")
      config.facet_fields.delete("department_facet")
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
    end
  end
end
