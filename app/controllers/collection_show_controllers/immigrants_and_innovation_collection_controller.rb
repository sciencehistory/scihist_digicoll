# A sub-class of collection show controller that is specifically for the Immigrants
# and Innnovation Oral History collection -- it's routed to for that collection in our routes.rb
#
# This lets us override configuration, to use the same facet config as the
# larger Oral History Collection custom controller page.
#
# At present we use standard collection show views.
module CollectionShowControllers
  class ImmigrantsAndInnovationCollectionController < CollectionShowController
    # we want the same facet config as oral history custom controller,
    # just copying all the config should be fine.
    copy_blacklight_config_from(CollectionShowControllers::OralHistoryCollectionController)
  end
end
