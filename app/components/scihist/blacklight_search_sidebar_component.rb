# frozen_string_literal: true

# A customized component for Blacklight only to CALL ORIGINAL, and then ADD ON TO END
# our list of "other search links"
#
# Configured in CatalogController, config.index.sidebar_component
#
class Scihist::BlacklightSearchSidebarComponent < ApplicationComponent
  ORIGINAL_COMPONENT_CLASS = Blacklight::Search::SidebarComponent


  def initialize(**kwargs)
    @original_initialize_kwargs = kwargs
    super()
  end

  def render_original_sidebar
    helpers.render ORIGINAL_COMPONENT_CLASS.new(**@original_initialize_kwargs)
  end
end
