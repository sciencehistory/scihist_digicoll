# frozen_string_literal: true

require 'kithe/blacklight_tools/bulk_loading_search_service'

class CatalogController < ApplicationController

  include BlacklightRangeLimit::ControllerOverride
  # Blacklight wanted Blacklight::Controller included in ApplicationController,
  # we do it just here instead.
  include Blacklight::Controller
  include Blacklight::Catalog

  # Not totally sure why we need this, instead of Rails loading all helpers automatically
  helper LocalBlacklightHelpers

  # a Blacklight override
  def render_bookmarks_control?
    false
  end

  # Tell Blacklight to include things in context, that will become
  # available to our custom SearchBuilder extensions
  def search_service_context
    {
      current_user: current_user
    }
  end

  self.search_service_class = Kithe::BlacklightTools::BulkLoadingSearchService
  Kithe::BlacklightTools::BulkLoadingSearchService.bulk_load_scope =
    -> { includes(:derivatives, :parent, leaf_representative: :derivatives)  }

  # What ViewModel class to use for a given search result on the results screen, for
  # Work or Collection. Called by _document_list.
  def view_model_class_for(model)
    if model.kind_of?(Work)
      WorkResultDisplay
    elsif model.kind_of?(Collection)
      CollectionResultDisplay
    else
      raise ArgumentError.new("Don't know proper search results ViewModel class for #{model}")
    end
  end
  helper_method :view_model_class_for


  # Tell Blacklight to recognize our custom filter_public_domain=1 as a constriants filter.
  # And override BL helper method to _display_ the filter_public_domain constraint,
  # as well as display the text query input constraint as a live search box/form allowing
  # user to change query inline, instead of just a label.
  module RenderQueryConstraintOverride
    def render_constraints_query(localized_params = params)
      render "query_constraint_as_form", params: localized_params
    end

    def query_has_constraints?(localized_params = params)
      super || SearchBuilder::PublicDomainFilter.filtered_public_domain?(localized_params)
    end
  end
  helper RenderQueryConstraintOverride

  # Cheesy way to override Blaclight helper method with call to super possible
  module SortHelperOverrides
    # Override Blacklight method, so "best match"/relevancy sort is not offered
    # unless there's a text query, cause it makes no sense in that case.
    def active_sort_fields
      if params[:q].present?
        super
      else
        # with no query, relevance doesn't make a lot of sense
        super.delete_if { |k| k.start_with?("score") }
      end
    end
  end
  helper SortHelperOverrides

  configure_blacklight do |config|
    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    # config.response_model = Blacklight::Solr::Response
    #
    ## Should the raw solr document endpoint (e.g. /catalog/:id/raw) be enabled
    # config.raw_endpoint.enabled = false

    config.default_per_page = 25

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
      rows: 25,
      qf: "text1_tesim^1000 text2_tesim^500 text3_tesim^100 text4_tesim^50 text_no_boost_tesim friendlier_id_ssi id",
      pf: "text1_tesim^1000 text2_tesim^500 text3_tesim^100 text4_tesim^50 text_no_boost_tesim friendlier_id_ssi id"
    }

    # solr path which will be added to solr base url before the other solr params.
    #config.solr_path = 'select'
    #config.document_solr_path = 'get'

    # items to show per page, each number in the array represent another option to choose from.
    # config.per_page = [25]

    # solr field configuration for search results/index views
    config.index.title_field = 'title_tsim'

    #config.index.display_type_field = 'format'
    #config.index.thumbnail_field = 'thumbnail_path_ss'

    # config.add_results_document_tool(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)

    config.add_results_collection_tool(:sort_widget)
    # config.add_results_collection_tool(:per_page_widget)
    # config.add_results_collection_tool(:view_type_group)

    # config.add_show_tools_partial(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)
    # config.add_show_tools_partial(:email, callback: :email_action, validator: :validate_email_params)
    # config.add_show_tools_partial(:sms, if: :render_sms_action?, callback: :sms_action, validator: :validate_sms_params)
    # config.add_show_tools_partial(:citation)

    # config.add_nav_action(:bookmark, partial: 'blacklight/nav/bookmark', if: :render_bookmarks_control?)
    # config.add_nav_action(:search_history, partial: 'blacklight/nav/search_history')

    # solr field configuration for document/show views
    #config.show.title_field = 'title_tsim'
    #config.show.display_type_field = 'format'
    #config.show.thumbnail_field = 'thumbnail_path_ss'

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    #
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # * If left unset, then all facet values returned by solr will be displayed.
    # * If set to an integer, then "f.somefield.facet.limit" will be added to
    # solr request, with actual solr request being +1 your configured limit --
    # you configure the number of items you actually want _displayed_ in a page.
    # * If set to 'true', then no additional parameters will be sent to solr,
    # but any 'sniffed' request limit parameters will be used for paging, with
    # paging at requested limit -1. Can sniff from facet.limit or
    # f.specific_field.facet.limit solr request params. This 'true' config
    # can be used if you set limits in :default_solr_params, or as defaults
    # on the solr side in the request handler itself. Request handler defaults
    # sniffing requires solr requests to be made with "echoParams=all", for
    # app code to actually have it echo'd back to see it.
    #
    # :show may be set to false if you don't want the facet to be drawn in the
    # facet bar
    #
    # set :index_range to true if you want the facet pagination view to have facet prefix-based navigation
    #  (useful when user clicks "more" on a large facet and wants to navigate alphabetically across a large set of results)
    # :index_range can be an array or range of prefixes that will be used to create the navigation (note: It is case sensitive when searching values)

    # The "show: :current_user" arg lets us limit facets to only showing up if someone is logged in

    config.add_facet_field "year_facet_isim", label: "Date", range: true
    config.add_facet_field "subject_facet", label: "Subject", limit: 5
    config.add_facet_field "creator_facet", label: "Creator", limit: 5
    config.add_facet_field "genre_facet", label: "Genre", limit: 5
    config.add_facet_field "format_facet", label: "Format", limit: 5
    config.add_facet_field "medium_facet", label: "Medium (Staff-only)", limit: 5, show: :current_user
    config.add_facet_field 'place_facet', label: "Place", limit: 5
    # TODO -- not showing up?
    config.add_facet_field 'language_facet', label: "Language", limit: 5
    config.add_facet_field "rights_facet", helper_method: :rights_label, label: "Rights", limit: 5
    config.add_facet_field 'department_facet', label: "Department", limit: 5
    config.add_facet_field 'exhibition_facet', label: "Exhibition", limit: 5
    config.add_facet_field 'project_facet',    label: "Project",    limit: 5


    # config.add_facet_field 'format', label: 'Format'
    # config.add_facet_field 'pub_date_ssim', label: 'Publication Year', single: true
    # config.add_facet_field 'subject_ssim', label: 'Topic', limit: 20, index_range: 'A'..'Z'
    # config.add_facet_field 'language_ssim', label: 'Language', limit: true
    # config.add_facet_field 'lc_1letter_ssim', label: 'Call Number'
    # config.add_facet_field 'subject_geo_ssim', label: 'Region'
    # config.add_facet_field 'subject_era_ssim', label: 'Era'

    # config.add_facet_field 'example_pivot_field', label: 'Pivot Field', :pivot => ['format', 'language_ssim']

    # config.add_facet_field 'example_query_facet_field', label: 'Publish Date', :query => {
    #    :years_5 => { label: 'within 5 Years', fq: "pub_date_ssim:[#{Time.zone.now.year - 5 } TO *]" },
    #    :years_10 => { label: 'within 10 Years', fq: "pub_date_ssim:[#{Time.zone.now.year - 10 } TO *]" },
    #    :years_25 => { label: 'within 25 Years', fq: "pub_date_ssim:[#{Time.zone.now.year - 25 } TO *]" }
    # }


    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    # config.add_index_field 'title_tsim', label: 'Title'

    # We aren't planning on using Blacklight default rendering from this
    # list of fields long term, but it helps with sanity check for now.
    # -jrochkind SHI

    config.add_index_field 'model_name_ssi'
    config.add_index_field 'friendlier_id_ssi'
    config.add_index_field 'text1_tesim'
    config.add_index_field 'text2_tesim'
    config.add_index_field 'text3_tesim'
    config.add_index_field 'text4_tesim'
    config.add_index_field 'text_no_boost_tesim'
    config.add_index_field 'admin_only_text_tesim'



    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display
    # config.add_show_field 'title_tsim', label: 'Title'

    # We aren't planning on using Blacklight default show action/view that uses
    # list of fields long term, but it helps with sanity check for now.
    # --jrochkind SHI

    config.add_show_field 'model_name_ssi'
    config.add_show_field 'friendlier_id_ssi'
    config.add_show_field 'text1_tesim'
    config.add_show_field 'text2_tesim'
    config.add_show_field 'text3_tesim'
    config.add_show_field 'text4_tesim'
    config.add_show_field 'text_no_boost_tesim'
    config.add_show_field 'admin_only_text_tesim'

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.

    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.

    config.add_search_field 'all_fields', label: 'All Fields'


    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.

    # config.add_search_field('title') do |field|
    #   # solr_parameters hash are sent to Solr as ordinary url query params.
    #   field.solr_parameters = {
    #     'spellcheck.dictionary': 'title',
    #     qf: '${title_qf}',
    #     pf: '${title_pf}'
    #   }
    # end

    # config.add_search_field('author') do |field|
    #   field.solr_parameters = {
    #     'spellcheck.dictionary': 'author',
    #     qf: '${author_qf}',
    #     pf: '${author_pf}'
    #   }
    # end

    # Specifying a :qt only to show it's possible, and so our internal automated
    # tests can test it. In this case it's the same as
    # config[:default_solr_parameters][:qt], so isn't actually neccesary.
    # config.add_search_field('subject') do |field|
    #   field.qt = 'search'
    #   field.solr_parameters = {
    #     'spellcheck.dictionary': 'subject',
    #     qf: '${subject_qf}',
    #     pf: '${subject_pf}'
    #   }
    # end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).

    config.add_sort_field "score desc, date_created_dtsi desc", label: "best match"
    config.add_sort_field "latest_year desc", label: "newest date"
    config.add_sort_field "earliest_year asc", label: "oldest date"
    config.add_sort_field "date_created_dtsi desc", label: "recently added", blank_query_default: true # will be used by our custom code as default sort when no query has been entered
    # TODO, limit to just admins, see that 'if'
    config.add_sort_field "date_created_dtsi asc", label: "oldest added" #, if: ->(controller, field) { controller.current_ability.current_user.staff? }
    config.add_sort_field "date_modified_dtsi desc", label: "date modified \u25BC" #, if: ->(controller, field) { controller.current_ability.current_user.staff? }
    config.add_sort_field "date_modified_dtsi asc", label: "date modified \u25B2" #, if: ->(controller, field) { controller.current_ability.current_user.staff? }


    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggestor
    config.autocomplete_enabled = false
    config.autocomplete_path = 'suggest'
    # if the name of the solr.SuggestComponent provided in your solrcongig.xml is not the
    # default 'mySuggester', uncomment and provide it below
    # config.autocomplete_suggester = 'mySuggester'
  end
end
