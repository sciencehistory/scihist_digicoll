# A sub-class of collection show controller that is specifically for the Oral History
# collection -- it's routed to for that collection in our routes.rb
#
# It lets us override configuration and views.
#
# index view is overridden to use splash page template for splash_page_only?
module CollectionShowControllers
  class BredigCollectionController < CollectionShowController
    configure_blacklight do |config|
      # A specialty facet just for this collection. Possibly temporary.
      config.add_facet_field "bredig_feature_facet", label: "Features", limit: 5
    end
  end
end
