# Not sure why we need this explicit require of a dependency, only in CI at the moment,
# but easy enough fix.
require 'view_component/version'

# This overrides Blacklight::ConstraintsComponent ONLY for the purpose of over-riding the
# default value for the initializer `query_constraint_component` keyword argument --
#
# So we can set our own custom ScihistQueryConstraintComponent, which is really what
# we wanted to do.
#
# Overridden at https://github.com/projectblacklight/blacklight/blame/13a8122fc6495e52acabc33875b80b51613d8351/app/components/blacklight/constraints_component.rb
#
# Configured for use in CatalogController, config.index.constraints_component
module Scihist
  class BlacklightConstraintsComponent < Blacklight::ConstraintsComponent

    # override just to change default value of `query_constraint_component`
    def initialize(*, search_state:, query_constraint_component: Scihist::BlacklightQueryConstraintComponent, **)
      @search_state = search_state
      super
    end

    # Override from Blacklight::ConstraintsComponent to:
    #
    # * Show even if there is a blank query, since we want to show the form
    #   so you can search within facet results.
    #
    # * This also lets us make sure we're controlling the params passed to
    #   our custom QueryComponent, since that is local code that is not updated
    #   by Blacklight!
    #
    # I don't entirely understand the original implementation where it adds
    # on `+ helpers.render(@facet_constraint_component`, we're leaving that out... seems
    # to be fine?  Sorry.
    def query_constraints
      # the `+` with @facet_constraint_component is copied from original implementation, and
      # I think is about "advanced search" feature?

      helpers.render(@query_constraint_component.new(
        search_state: @search_state
      )) + helpers.render(@facet_constraint_component.with_collection(clause_presenters.to_a, **@facet_constraint_component_options))
    end
  end
end
