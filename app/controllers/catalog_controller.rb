# frozen_string_literal: true

require 'kithe/blacklight_tools/bulk_loading_search_service'

class CatalogController < ApplicationController
  before_action :redirect_hash_facet_params, only: :index
  before_action :redirect_legacy_query_urls, only: :index

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
    -> { includes(:parent, :leaf_representative)  }

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

  module Blacklight::CatalogHelperBehavior
    # These three methods
    # were outputting links (rel="alternate") in the HTML head tag that sent bots
    # to crawl RSS, atom, and json versions
    # of our search results, which we are not offering yet.
    # and we are overrriding them so they output nothing instead.
    #
    # Overridden methods:
    # https://github.com/projectblacklight/blacklight/blob/6b5c5b823d96327282aa0ce401946be0cc267f49/app/helpers/blacklight/catalog_helper_behavior.rb
    # Template that calls them:
    # https://github.com/projectblacklight/blacklight/blob/6b5c5b823d96327282aa0ce401946be0cc267f49/app/views/catalog/_search_results.html.erb
    #
    # See issue https://github.com/sciencehistory/scihist_digicoll/pull/497 for more details.
    def rss_feed_link_tag(options = {})
    end
    def atom_feed_link_tag(options = {})
    end
    def json_api_link_tag(options = {})
    end
  end

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
        super.delete_if { |k| k == "relevance" }
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
      qf: "text1_tesim^1000 text2_tesim^500 text3_tesim^100 text4_tesim^50 text_no_boost_tesim^10 friendlier_id_ssi id^10 searchable_fulltext^0.5",
      pf: "text1_tesim^1000 text2_tesim^500 text3_tesim^100 text4_tesim^50 text_no_boost_tesim^10 friendlier_id_ssi id^10 searchable_fulltext^5",


      # HIGHLIGHTING-related params, full snippets from fulltext matches
      #
      # https://lucene.apache.org/solr/guide/8_0/highlighting.html
      #
      "hl" => "true",
      "hl.method" => "unified",
      "hl.fl" => "searchable_fulltext",
      "hl.usePhraseHighlighter" => "true",
      "hl.snippets" => 3,
      "hl.encoder" => "html",
      # Biggest current transcript seems to be OH0624 with 817,139 chars.
      # Set maxAnalyzed Chars to two million? I dunno. Solr suggests if we
      # have things set up right, it ought to be able to handle very big, unclear.
      "hl.maxAnalyzedChars" => "2000000",
      "hl.offsetSource" => "postings",
      #
      "hl.bs.type" => "WORD",
      "hl.fragsize" => "140",
      "hl.fragsizeIsMinimum" => "true"
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
    config.add_facet_field 'published_bsi',    label: "Visibility (Staff-only)", show: :current_user, helper_method: :visibility_facet_labels



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
    # We use feature to have sort field name (which shows up in URL) be specified
    # by us, rather than be the Solr sort value, so it is independent of solr field
    # names and config, and we can keep our URLs persistent.
    # http://jessiekeck.com/customizing-blacklight/sort_fields/

    config.add_sort_field("relevance") do |field|
      field.label = "best match"
      field.sort = "score desc, date_created_dtsi desc"
    end

    config.add_sort_field("newest_date") do |field|
      field.label = "newest date"
      field.sort = "latest_year desc"
    end

    config.add_sort_field("oldest_date") do |field|
      field.label = "oldest date"
      field.sort = "earliest_year asc"
    end

    config.add_sort_field("recently_added") do |field|
      field.label = "recently added"
      field.sort = "date_created_dtsi desc"
      # will be used by our custom code as default sort when no query has been entered
      field.blank_query_default = true
    end

    # limit to just available for logged-in admins, with `if ` param

    config.add_sort_field("oldest_added") do |field|
      field.label = "oldest added"
      field.sort = "date_created_dtsi asc"
      field.if = ->(controller, field) { controller.current_user }
    end

    config.add_sort_field("date_modified_desc") do |field|
      field.label = "date modified \u25BC"
      field.sort = "date_modified_dtsi desc"
      field.if = ->(controller, field) { controller.current_user }
    end

    config.add_sort_field("date_modified_asc") do |field|
      field.label = "date modified \u25B2"
      field.sort = "date_modified_dtsi asc"
      field.if = ->(controller, field) { controller.current_user }
    end


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

  LEGACY_SORT_REDIRECTS = {
    "latest_year desc" => "newest_date",
    "earliest_year asc" => "oldest_date",
    "score desc, system_create_dtsi desc" => "relevance",
    "system_create_dtsi desc" => "recently_added",
    "system_create_dtsi asc" => "oldest_added",
    "system_modified_dtsi desc" => "date_modified_desc",
    "system_modified_dtsi asc" => "date_modified_asc"
  }

  LEGACY_FACET_REDIRECTS = {
    "subject_sim" => "subject_facet",
    "maker_facet_sim" => "creator_facet",
    "genre_string_sim" => "genre_facet",
    "resource_type_sim" => "format_facet",
    "medium_sim" => "medium_facet",
    "place_facet_sim" => "place_facet",
    "language_sim" => "language_facet",
    "rights_sim" => "rights_facet",
    "division_sim" => "department_facet",
    "exhibition_sim" => "exhibition_facet"
  }

  # When posting on facebook, it modifies our facet params from eg `?f[facet_name][]=value` to
  # `?f[facet_name][0]=value`. This breaks blacklight. We fix and REDIRECT to fixed URL, to
  # maintain having one canonical URL.
  #
  # Future versions of Blacklight may accomodate these malformed URLs through an alternate
  # strategy and not need this redirect: https://github.com/projectblacklight/blacklight/pull/2313
  def redirect_hash_facet_params
    if params[:f].respond_to?(:transform_values) && params[:f].values.any? { |x| x.is_a?(Hash) }
      original_f_params = params[:f].to_unsafe_h
      corrected_params = {}

      corrected_params[:f] = original_f_params.transform_values do |value|
        value.is_a?(Hash) ? value.values : value
      end

      redirect_to helpers.safe_params_merge_url(corrected_params), :status => :moved_permanently
    end
  end

  def redirect_legacy_query_urls
    corrected_params = {}

    if params[:f].respond_to?(:keys) && params[:f].keys.any? { |k| LEGACY_FACET_REDIRECTS.keys.include?(k.to_s) }
      # to_unsafe_h should be fine here, arbitrary :f params for facet limiting are expected and not a vulnerability.
      corrected_params[:f] = params[:f].transform_keys { |k| LEGACY_FACET_REDIRECTS[k.to_s] || k }.to_unsafe_h
    end

    if new_sort = LEGACY_SORT_REDIRECTS[params[:sort]]
      corrected_params[:sort] = new_sort
    end

    if corrected_params.present?
      redirect_to helpers.safe_params_merge_url(corrected_params), :status => :moved_permanently
    end
  end
end
