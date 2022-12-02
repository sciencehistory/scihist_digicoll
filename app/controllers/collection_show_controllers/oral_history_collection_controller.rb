# A sub-class of collection show controller that is specifically for the Oral History
# collection -- it's routed to for that collection in our routes.rb
#
# It lets us override configuration and views.
#
# index view is overridden to use splash page template for splash_page_only?
module CollectionShowControllers
  class OralHistoryCollectionController < CollectionShowController
    # "Projects" we want to list on splash page are actually "Collection" objects.
    # We just hard-code their friendlier_id's here (should we make this configurable
    # in ENV instead?)
    NANOTECHNOLOGY_FRIENDLIER_ID = 'zedby6n'
    MASS_SPECTROMETRY_FRIEDLIER_ID = 'htlihxv'
    TOXIC_SUBSTANCES_FRIENDLIER_ID = 'olbbze5'
    REACH_AMBLER_FRIENDLIER_ID = 'ycpwcmp'
    # order matters, the order we want them displayed:
    PROJECT_COLLECTION_FRIENDLIER_IDS =
      [TOXIC_SUBSTANCES_FRIENDLIER_ID, MASS_SPECTROMETRY_FRIEDLIER_ID, NANOTECHNOLOGY_FRIENDLIER_ID, REACH_AMBLER_FRIENDLIER_ID]

    # in splash_page_only mode, we'll fetch a facet count for each of these queries,
    # to label our canned queries with counts.
    SPLASH_CANNED_QUERIES = {
      synchronized_audio: 'oh_feature_facet:"Synchronized audio"',
      women_in_science: 'subject_facet:"Women in science"',
      nobel_prize: 'subject_facet:"Nobel Prize winners"',
    }

    def blacklight_config
      if splash_page_only?
        self.splash_page_blacklight_config
      else
        super
      end
    end

    # Should be equivalent to:
    # ->(controller, field) { controller.can?(:access_staff_functions) }
    # but was not able to get this syntax to work.
    def can_see_all_search_facets?
      can? :access_staff_functions
    end


    # Collections we want to list as "projects", ordered by same order as their ids in
    # PROJECT_COLLECTION_FRIENDLIER_IDS
    helper_method def project_list
      @project_list ||= Collection.includes(:leaf_representative).
        where(friendlier_id: PROJECT_COLLECTION_FRIENDLIER_IDS).
        sort_by { |c| PROJECT_COLLECTION_FRIENDLIER_IDS.index(c.friendlier_id) }
    end

    # some kinda ugly ActiveRecord/SQL to do one fetch to get public member counts for our
    # project list in one fetch. Result will be hash where key is collection ID (UUID pk), and
    # value is count of public members
    #
    # We don't have collection membership in Solr, or we could use our "canned queries" mechanism
    # from existing Solr query, instead we have to do an additional SQL query here, and a
    # kind of convoluted one at that.
    #
    # We're only doing published counts, even if user is logged in, not worth it.
    def project_counts
      @project_counts ||= Kithe::Model.joins(:contains_contained_by).
        where(published: true, contains_contained_by: {container_id: project_list.collect(&:id) }).
        group(:container_id).
        count
    end

    helper_method def count_for_project(collection)
      project_counts[collection.id].to_i
    end

    # Assuming we added a facet.query to solr query, we look up the count returned
    # from the solr response.
    def canned_query_count(key)
      query = SPLASH_CANNED_QUERIES[key.to_sym]
      raise ArgumentError.new("key must be in SPLASH_CANNED_QUERIES hash") if query.nil?
      @response.facet_counts["facet_queries"][query]
    end
    helper_method :canned_query_count


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

    # Array of at most 3 people born on this day, returned as
    # IntervieweeBiography.
    #
    # We do a non-indexed query against postgres (using `%` and `like` to match end
    # of yyyy-mm-dd string), but with ~1000 IntervieweeBiographies,
    # it's not a big deal. we eager-load to avoid n+1.
    #
    # We could try to find some way to cache this since it only changes from day to day,
    # but, for now we're seeing if maybe it's quick enough we don't need to bother.
    def born_on_this_day_biographies
      @born_on_this_day ||= begin
        query_date = Date.today

        IntervieweeBiography.
          references(oral_history_content: :work).
          where("interviewee_biographies.json_attributes -> 'birth' ->> 'date' like '%-#{query_date.strftime("%m-%d")}'").
          where(oral_history_content: { kithe_models: { published: true}}).
          includes(oral_history_content: { work: :leaf_representative }).
          order("random()").
          limit(3).
          to_a
      end
    end
    helper_method :born_on_this_day_biographies

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
        facet_config.if = :can_see_all_search_facets?
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

    # We're going to create a second blacklight_config based on the first, but
    # for use when we are in splash_page_only mode, to get some counts we need,
    # but not actually search results.
    class_attribute :splash_page_blacklight_config
    self.splash_page_blacklight_config = self.blacklight_config.inheritable_copy(self)
    self.splash_page_blacklight_config.configure do |config|
      # no rows, no ordinary search results needed
      config.default_solr_params[:rows] = 0

      # No normal facet_fields, clear em
      config.facet_fields.clear

      # But some facet.query facet fields we'll use for fetching counts for
      # our canned queries.
      config.default_solr_params["facet.query"] = SPLASH_CANNED_QUERIES.values.dup
    end


  end
end
