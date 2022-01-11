# frozen_string_literal: true

require 'kithe/blacklight_tools/bulk_loading_search_service'

class CatalogController < ApplicationController
  before_action :redirect_hash_facet_params, only: :index
  before_action :redirect_legacy_query_urls, only: :index
  before_action :catch_bad_blacklight_params, only: [:index, :facet]
  before_action :swap_range_limit_params_if_needed, only: [:index, :facet]
  before_action :catch_bad_request_headers, only: :index

  before_action :screen_params_for_range_limit, only: :range_limit

  # Blacklight wanted Blacklight::Controller included in ApplicationController,
  # we do it just here instead.
  include Blacklight::Controller
  include Blacklight::Catalog
  include BlacklightRangeLimit::ControllerOverride

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

  # What ViewComponent class to use for a given search result on the results screen, for
  # Work or Collection. Called by _document_list.
  def view_component_class_for(model)
    if model.kind_of?(Work)
      SearchResult::WorkComponent
    elsif model.kind_of?(Collection)
      SearchResult::CollectionComponent
    else
      raise ArgumentError.new("Don't know proper search results ViewModel class for #{model}")
    end
  end
  helper_method :view_component_class_for


  # OVERRIDE of Blacklight method. Blacklight by default takes ANY kind
  # of Solr error (could be Solr misconfiguraiton or down etc), and just swallows
  # it, redirecting to Blacklight search page with a message "Sorry, I don't understand your search."
  #
  # This is wrong.  It's misleading feedback for user for something that is usually not
  # something they can do something about, and it suppresses our error monitoring
  # and potentially misleads our uptime checking.
  #
  # We just want to actually raise the error!
  #
  # Additionally, Blacklight/Rsolr wraps some errors that we don't want wrapped, mainly
  # the Faraday timeout error -- we want to be able to distinguish it, so will unwrap it.
  private def handle_request_error(exception)
    if exception.is_a?(Blacklight::Exceptions::InvalidRequest)
      # The exception we have can have a #cause, which can itelf have
      # a #cause, etc.  Revealing exceptions which were previously rescued and
      # re-raised. Look up the `cause` chain and if we have a Faraday::TimeoutError,
      # raise it directly instead of the generic wrapping
      # Blacklight::Exceptions::InvalidRequest!

      e = exception
      until e.cause.nil?
        if e.kind_of?(Faraday::TimeoutError)
          raise e
        end
        e = e.cause
      end
    end

    # Raise the rescued exception, replacing default Blacklight behavior
    # of rescuing with a message to end-user.
    raise exception
  end

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

    # We override this in order to customize how the query text constraint is displayed,
    # to make it a little editable search box.
    #
    # Blacklight really doesn't want us to override this anymore as of somewhere around blacklight 7.12
    # But we can't find any other way to do this customization, so it remains for now.
    # We do try to make it trigger as few deprecation warnings as possible.
    def render_constraints_query(params_or_search_state = search_state)
      localized_params = _scihist_convert_to_params(params_or_search_state)
      render "query_constraint_as_form", params: localized_params
    end

    def query_has_constraints?(params_or_search_state = search_state)
      localized_params = _scihist_convert_to_params(params_or_search_state)

      # actually have to pass localized_params in super, as oppoosed to no-arg `super`,
      # to avoid breaking blacklight_range_limit by passing the NEW default arg
      # Blacklight::SearchState that it's not expecting. This is hard to explain,
      # but it's how it is...
      #
      super(localized_params) || SearchBuilder::PublicDomainFilter.filtered_public_domain?(localized_params)
    end

    private

    # recent blacklight has switched a lot of arguments from `params` hash to
    # a Blacklight::SearchState object, but a lot of our code wants the params,
    # we'll switch em back.
    def _scihist_convert_to_params(params_or_search_state)
      if params_or_search_state.is_a? Blacklight::SearchState
        # search_state.params returns an ordinary hash, which is fine for most
        # of our code, but things get complex with blacklight_range_limit,
        # let's make it an actual ActionController::Parameters like it used to be,
        # keeps everything strictly backwards compat and working better.
        ActionController::Parameters.new(params_or_search_state.params)
      elsif params_or_search_state.is_a? ActionController::Parameters
        params_or_search_state
      else
        raise ArgumentError, "in Blacklight override, we expected SearchState or Parameters, but got something unexpected: #{params_or_search_state}"
      end

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
    # We overide to use custom sub-class for Solr HTTP retries
    config.repository_class = Scihist::BlacklightSolrRepository


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
      qf: "text1_tesim^1000 text2_tesim^500 text3_tesim^100 text4_tesim^50 description_text4_tesim^50 text_no_boost_tesim^10 friendlier_id_ssi id^10 searchable_fulltext^0.5 searchable_fulltext_language_agnostic^0.5",
      pf: "text1_tesim^1500 text2_tesim^1200 text3_tesim^600 text4_tesim^120 description_text4_tesim^120 text_no_boost_tesim^55 friendlier_id_ssi id^55 searchable_fulltext^12 searchable_fulltext_language_agnostic^12",


      # HIGHLIGHTING-related params, full snippets from fulltext matches
      #
      # https://lucene.apache.org/solr/guide/8_0/highlighting.html
      #
      "hl" => "true",
      "hl.method" => "unified",
      "hl.fl" => SearchResult::BaseComponent::HIGHLIGHT_SOLR_FIELDS.join(" "),
      "hl.usePhraseHighlighter" => "true",
      "hl.snippets" => SearchResult::BaseComponent::MAX_HIGHLIGHT_SNIPPETS,
      "hl.encoder" => "html",
      # Biggest current transcript seems to be OH0624 with 817,139 chars.
      # Set maxAnalyzed Chars to two million? I dunno. Solr suggests if we
      # have things set up right, it ought to be able to handle very big, unclear.
      "hl.maxAnalyzedChars" => "2000000",
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
      field.sort = "date_published_dtsi desc, date_created_dtsi desc"
      # will be used by our custom code as default sort when no query has been entered
      field.blank_query_default = true
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

    config.add_sort_field("date_created_asc") do |field|
      field.label = "date created \u25BC"
      field.sort = "date_created_dtsi asc"
      field.if = ->(controller, field) { controller.current_user }
    end

    config.add_sort_field("date_created_desc") do |field|
      field.label = "date created \u25B2"
      field.sort = "date_created_dtsi desc"
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

  # Some bad actors sometimes send query params that Blacklight doesn't expect and
  # can't handle. They look like they are scanning for vulnerabilities which don't
  # apply to us and it's fine that they get an error, but let's avoid them resulting
  # in uncaught exceptions reported in our error tracker, while giving a nice error response.
  #
  # We use `respond_to?(:to_hash)` to try to allow either Hash or ActionController::Params,
  # since it seems like in specs it can be straight Hash and this is a weird implementation detail.
  #
  # A render in a before_action will halt further processing, as intended.
  def catch_bad_blacklight_params
    # Lazily doing errmsg formatting as an inline proc, to avoid having to make another method.
    # We want to try to output useful error message, but sometimes that raises too.
    param_display = lambda do |param_hash|
      begin
        "Invalid URL query parameter f=#{param_hash.to_unsafe_h.to_param}"
      rescue StandardError
        "Invalid URL query parameter f=#{param_hash.to_s}"
      end
    end

    # someone trying to do an injection attack in the `page` param somehow
    # triggered a Solr 400, let's nip it in the bud.
    if params[:page].present? && params[:page] !~ /\A\d+\Z/
      render(plain: "illegal page query parameter", status: 400) && return
    end

    # Correct range facets look like:
    # params[:range] == {"year_facet_isim"=>{"begin"=>"1900", "end"=>"1950"}}
    # &range%5Byear_facet_isim%5D%5Bbegin%5D=1900&range%5Byear_facet_isim%5D%5Bend%5D=1950
    #
    # Can also be empty string values in there.
    #
    # Make sure it has that shape, or just abort, becuase it is likely to make blacklight_range_limit
    # choke and uncaught excpetion 500.
    #
    # Additionally, newlines and other things that aren't just integers can cause an error too,
    # just insist on \d+ or empty string only.

    if params[:range].present?
      unless params[:range].respond_to?(:to_hash)
        render(plain: "Invalid URL query parameter range=#{param_display.call(params[:range])}", status: 400) && return
      end

      params[:range].each_pair do |_facet_key, range_limits|
        unless range_limits.respond_to?(:to_hash) && range_limits[:begin].is_a?(String) && range_limits[:end].is_a?(String) &&
          range_limits[:begin] =~ /\A\d*\z/ && range_limits[:end] =~ /\A\d*\z/
          render(plain: "Invalid URL query parameter range=#{param_display.call(params[:range])}", status: 400) && return
        end
      end
    end


    # facet param :f is a hash of keys and values, where each key is a facet name, and
    # each value is an *array* of strings. Anything else, we should reject it as no good,
    # because Blacklight is likely to raise an uncaught exception over it.
    #
    # eg &f=expect%3A%2F%2Fdir
    if params[:f].present?
      if !params[:f].respond_to?(:to_hash)
        render(plain: "Invalid URL query parameter f=#{param_display.call(params[:f])}", status: 400) && return
      end

      params[:f].each do |facet, value|
        unless facet.is_a?(String)
          render(plain: "Invalid URL query parameter f=#{param_display.call(params[:f])}", status: 400) && return
        end

        unless value.is_a?(Array) && value.all? {|v| v.is_a?(String)}
          render(plain: "Invalid URL query parameter f=#{param_display.call(params[:f])}", status: 400) && return
        end
      end
    end
  end


  # Out of the box, Blacklight allows for search results
  # to be requested as (and served as) JSON.
  # That feature is not working, and we have no plans to fix it,
  # but as a courtesy (and to avoid noisy 500 errors) we're providing an actual
  # 406 error message, consistent with the behavior on other controllers
  # on our app that don't handle JSON requests.
  # See discussion at:
  # https://github.com/sciencehistory/scihist_digicoll/issues/201
  # https://github.com/sciencehistory/scihist_digicoll/issues/924
  def catch_bad_request_headers
    if request.headers["accept"] == "application/json"
      render plain: "Invalid request header: we do not provide a JSON version of our search results.", status: 406
    end
  end


  LEGACY_SORT_REDIRECTS = {
    "latest_year desc" => "newest_date",
    "earliest_year asc" => "oldest_date",
    "score desc, system_create_dtsi desc" => "relevance",
    "system_create_dtsi desc" => "recently_added",
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

  # If the user enters an impossible date range with begin after end, swap the dates by actually
  # mutating `params` (ugly but it works), instead of letting blacklight_range_limit raise.
  def swap_range_limit_params_if_needed
    return if params.empty?

    start_date = params.dig(:range, :year_facet_isim, :begin)
    end_date   = params.dig(:range, :year_facet_isim, :end)

    return unless start_date.present? && end_date.present?
    return unless start_date.to_i > end_date.to_i

    params['range']['year_facet_isim']['begin'] = end_date
    params['range']['year_facet_isim']['end']   = start_date
  end

  # When a user (in practice, a bot) makes a call directly to /catalog/range_limit
  # rather than the usual /catalog?q=&range, this bypasses the preprocessing normally
  # performed by the `before_action` methods for #index, which supplies a
  # range_start and range_end parameter and ensures they are in the correct order,
  # then makes a second request to #range_limit .
  def screen_params_for_range_limit
    if (params['range_end'].nil?) ||
      (params['range_start'].nil?) ||
      (params['range_start'].to_i > params['range_end'].to_i)
        render plain: "Calls to range_limit should have a range_start " +
          "and a range_end parameter, and range_start " +
          "should be before range_end.", status: 406
    end
  end
end
