require 'resque/server'

Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  class CanAccessStaffFunctionsConstraint
    def self.matches?(request)
      AccessPolicy.new(request.env['warden']&.user).can? :access_staff_functions
    end
  end

  # bot detection challenge
  post "/challenge", to: "bot_challenge_page/bot_challenge_page#verify_challenge"
  get "/challenge", to: "bot_challenge_page/bot_challenge_page#challenge", as: :bot_detect_challenge

  # custom error pages
  # https://www.marcelofossrj.com/recipe/2019/04/14/custom-errors.html
  get "/404", to: "errors#not_found", :via => :all
  get "/422", to: "errors#unacceptable", :via => :all
  get "/500", to: "errors#internal_error", :via => :all

  # Oral History legacy redirects, come first in routes file so they'll match first
  # for requests to old oral history host oh.sciencehistory.org
  OH_LEGACY_REDIRECTS ||= YAML.load_file(Rails.root + "config/oral_history_legacy_redirects.yml").freeze
  constraints host: ScihistDigicoll::Env.lookup!(:oral_history_legacy_host) do
    # OH home page, send to new OH collection page
    root as: false, to: redirect { "#{ScihistDigicoll::Env.lookup!("app_url_base")}/collections/#{ScihistDigicoll::Env.lookup!("oral_history_collection_id")}"  }


    # Links to search results in legacy OH site should redirct to search of OH collection.
    # We only support basic query term, not fielded search or facets.
    get "search/site/*query", to: redirect { |path_params, req|
      "#{ScihistDigicoll::Env.lookup!("app_url_base")}/collections/#{ScihistDigicoll::Env.lookup!("oral_history_collection_id")}?q=#{URI.encode_www_form_component(path_params[:query]).gsub("+", "%20")}"
    }
    get "search/oh/*query", to: redirect { |path_params, req|
      "#{ScihistDigicoll::Env.lookup!("app_url_base")}/collections/#{ScihistDigicoll::Env.lookup!("oral_history_collection_id")}?q=#{URI.encode_www_form_component(path_params[:query]).gsub("+", "%20")}"
    }

    get '/oral-histories/projects', to: redirect('https://sciencehistory.org/oral-history-projects')

    # Does it match one of our OH_LEGACY_REDIRECTS? Then redirect it!
    get '*path', constraints: ->(req) { OH_LEGACY_REDIRECTS.has_key?(req.path.downcase) }, to: redirect { |params, req|
      "#{ScihistDigicoll::Env.lookup!("app_url_base")}#{OH_LEGACY_REDIRECTS[req.path.downcase]}"
    }

    # Is Oral history host but we don't recognize it? Give them the customly helpful
    # legacy OH 404 . Even ".pdf" links, give them a 404 in html.
    get "*path", to: "static#oh_legacy_url_not_found", format: false, defaults: { format: "html" }
  end


  root 'homepage#index'

  match 'oai', to: "oai_pmh#index", via: [:get, :post], as: :oai_provider
  # https://github.com/plataformatec/devise/wiki/how-to:-change-the-default-sign_in-and-sign_out-routes
  # We aren't using :registration cause we don't want to allow self-registration,
  # We aren't using session cause we define em ourselves manually.
  devise_for :users,
    skip: [:session, :registration],
    controllers: if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
      { passwords: 'passwords', omniauth_callbacks: 'auth',  }
    else
      { passwords: 'passwords' }
    end

  if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    devise_scope :user do
      get 'logout', to:'auth#sso_logout'
    end
  else
    devise_scope :user do
      get  'login',  to: 'devise/sessions#new',     as: :new_user_session
      post 'login',  to: 'devise/sessions#create',  as: :user_session
      get  'logout', to: 'devise/sessions#destroy'
    end
  end

  # Dynamic robots.txt
  # this will fall through to ./views/application/robots.text.erb, no need for an action method
  get 'robots.txt', to: "application#robots", format: "text"

  # On-demand derivatives
  constraints(derivative_type: Regexp.union(OnDemandDerivative.derivative_type_definitions.keys.collect(&:to_s))) do
    get "works/:id/:derivative_type", to: "on_demand_derivatives#on_demand_status", as: :on_demand_derivative_status
  end

  # By-request oral history stuff
  get "works/:work_friendlier_id/request_oral_history", to: "oral_history_requests#new", as: 'oral_history_request_form'
  post "request_oral_history", to: "oral_history_requests#create", as: 'request_oral_history'
  get "oral_history_requests", to: "oral_history_requests#index", as: "oral_history_requests"
  get "oral_history_requests/:id", to: "oral_history_requests#show", as: "oral_history_request"

  resource :oral_history_session, only: [:new, :create, :destroy] do
    member do
      get 'login/:token', action: :login, as: :login
    end
  end


  # public-facing routes
  resources :works, only: [:show]

  # JSON info for scihist_viewer image viewer
  get '/works/:id/viewer_images_info' => 'works#viewer_images_info',
    defaults: {format: "json"},
    format: false,
    as: :viewer_images_info

  # display search-inside-book results in our local viewer
  get '/works/:id/viewer_search' => 'works#viewer_search',
    defaults: {format: "json"},
    format: false,
    as: :viewer_search

  get 'works/:id/transcription' => "works#transcription",
    defaults: {format: 'txt'},
    format: false,
    as: :work_transcription_download

  get 'works/:id/english_translation' => "works#english_translation",
    defaults: {format: 'txt'},
    format: false,
    as: :work_english_translation_download

  get 'works/:id/lazy_member_images' => "works#lazy_member_images",
    format: false,
    defaults: {format: 'html'},
    as: :lazy_member_images

  # Make the viewer  URL lead to ordinary show page, so JS can pick it up and launch viewer.
  get '/works/:id/viewer/:viewer_member_id(.:format)' => 'works#show', as: :viewer


  # note /filter says we might have a filter, otherwise an ID comes next from
  # another route.
  get '/collections(/filter/:department_filter)', to: "collections_list#index", as: :collections,
    constraints: { department_filter: Regexp.union(CollectionsListController::DEPARTMENT_FILTERS.keys)}

  # Our collections show controller provides a Blacklight search, so needs
  # some additional routes for various search behaviors too.
  #
  # Additioally, we define this as a "routing concern" (https://guides.rubyonrails.org/routing.html#routing-concerns)
  # so we can *re-use* it for an overridden controller for *specific* collections, where we want
  # a custom landing page. See oral history example below.
  concern :collection_showable do |options|
    options[:controller] ||= "collection_show"

    # routing method name, needs ot be unique each time we use this.
    # By default "collection" (eg collection_path collection_url), based on
    # options[:controller]
    options[:as] ||= options[:controller].to_s.sub(/_show$/, '').to_sym

    get "collections/:collection_id", to: "#{options[:controller]}#index", as: options[:as]
    get "collections/:collection_id/range_limit" => "#{options[:controller]}#range_limit"
    get "collections/:collection_id/range_limit_panel" => "#{options[:controller]}#range_limit_panel"
    get "collections/:collection_id/facet" => "#{options[:controller]}#facet"
  end


  # Overrides of collection show controller for specific collections with custom
  # pages, needs to come BEFORE main collection routing, to take precedence. We use
  # Rails routing constraints feature to say if collection_id is a specific one, use
  # this other controller.

  if ScihistDigicoll::Env.lookup(:oral_history_collection_id).present?
    constraints(collection_id: ScihistDigicoll::Env.lookup(:oral_history_collection_id)) do
      concerns :collection_showable, controller: "collection_show_controllers/oral_history_collection"
    end
  end

  if ScihistDigicoll::Env.lookup(:immigrants_and_innovation_collection_id).present?
    constraints(collection_id: ScihistDigicoll::Env.lookup(:immigrants_and_innovation_collection_id)) do
      concerns :collection_showable, controller: "collection_show_controllers/immigrants_and_innovation_collection"
    end
  end


  # and a special controller for bredig, that at least initially only has customized facets
  if ScihistDigicoll::Env.lookup(:bredig_collection_id).present?
    constraints(collection_id: ScihistDigicoll::Env.lookup(:bredig_collection_id)) do
      concerns :collection_showable, controller: "collection_show_controllers/bredig_collection"
    end
  end


  # and our default collection show page routing
  concerns :collection_showable


  # and the special "featured topics" or "focuses" that appear like collections
  # but are actually formed from canned searches.
  get "focus", to: "featured_topics_list#index", as: :featured_topics
  get "focus/:slug", to: "featured_topic#index", as: :featured_topic
  get "focus/:slug/range_limit" => "featured_topic#range_limit"
  get "focus/:slug/range_limit_panel" => "featured_topic#range_limit_panel"
  get "focus/:slug/facet" => "featured_topic#facet"


  # the file_category is in here solely so we can distinguish in robots.txt,
  # we want the file type in the URL. It's not actually used by controller.
  #
  # download_path(asset.file_category, asset)
  # download_url(asset.file_category, asset)
  get "downloads/orig/:file_category/:asset_id", to: "downloads#original", as: :download

  # download_derivative_path(asset, "thumb_small")
  # download_derivative_url(asset, "thumb_small")
  get "downloads/deriv/:asset_id/:derivative_key", to: "downloads#derivative", as: :download_derivative


  # We redirect the old version of /downloads/:asset_id, before we changed to above
  # with status 301 Moved Permanently
  get "downloads/:asset_id", status: 301, to: redirect {|path_params, req|
    file_category = Asset.find_by_friendlier_id(path_params[:asset_id])&.file_category

    unless file_category
      # Rails will catch and handle with a 404.
      raise ActionController::RoutingError.new("no such asset as #{path_params[:asset_id]}")
    end

    "/downloads/orig/#{file_category}/#{path_params[:asset_id]}"
  }
  # and old version of derivative /downloads/:asset_id/:derivative_key, in
  # case some are in google images etc.
  get "downloads/:asset_id/:derivative_key", to: redirect(path: '/downloads/deriv/%{asset_id}/%{derivative_key}'), status: 301

  ##
  # Blacklight-generated routes, that were then modified a bit by us to take
  # out stuff we're not using.
  #

      # TODO: Can we get away without actuallymounting Blacklight, just using the CatalogController?
      # mount Blacklight::Engine => '/'
      concern :searchable, Blacklight::Routes::Searchable.new
      resource :catalog, only: [], as: 'catalog', path: '/catalog', controller: 'catalog' do
        concerns :searchable
        concerns :range_searchable # for blacklight_range_limit
      end

      # We aren't using default Blacklight action for 'show' item, instead using our
      # own ActiveRecord-model based show, so don't need to route SolrDocumentController...
      # we think, at least for now.
      #
      # concern :exportable, Blacklight::Routes::Exportable.new
      # resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
      #   concerns :exportable
      # end

      # We aren't using bookmarks, and don't have to route them
      # --jrochkind
      # resources :bookmarks do
      #   concerns :exportable

      #   collection do
      #     delete 'clear'
      #   end
      # end

      # We do not implement rss / atom / json search results (or plan to implement them).
      # Thus, catch_bad_format_param in catalog_controller.rb sends e.g. /focus/alchemy.json to a 406.

  ##
  # End Blacklight-generated routes
  ##

  # Routes will even only _show up_ for users who can :access_staff_functions; this applies
  # to internal rack apps we're mounting here too, like shrine upload endpoints,
  # is one reason to use a constraint.
  namespace :admin do
    root to: "works#index"

    resources :users, except: [:destroy, :show] do
      member do
        post "send_password_reset" unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
      end
    end

    # Admin page for work management, we'll handle public view elsewhere
    resources :works do
      member do
        get "reorder_members", to: "works#reorder_members_form"
        put "reorder_members"
        put "demote_to_asset"
        put "publish"
        put "unpublish"
        put "submit_ohms_xml"
        get "download_ohms_xml"
        put "remove_ohms_xml"
        put "set_review_requested"
        put "submit_searchable_transcript_source"
        get "download_searchable_transcript_source"
        put "remove_searchable_transcript_source"
        put "create_combined_audio_derivatives"
        put "update_oh_available_by_request"
        patch "update_oral_history_content"
      end
      collection do
        get 'batch_update', to: "works#batch_update_form"
        post 'batch_update'
        put 'batch_publish_toggle'
      end
    end

    get "/works/:parent_id/ingest", to: "assets#display_attach_form", as: "asset_ingest"
    post "/works/:parent_id/ingest", to: "assets#attach_files"


    put "/asset_files/:id/submit_hocr_and_textonly_pdf",            to: "assets#submit_hocr_and_textonly_pdf"

    resources :collections, except: [:show]

    # Note "assets" is Rails reserved word for routing, oops. So we use
    # asset_files.
    resources :assets, path: "asset_files", except: [:new, :create] do
      member do
        put "convert_to_child_work"
        put "setup_work_from_pdf_source"
      end
    end

    # a cheesy way to provide this one-off action
    put "/active_encode_status/:active_encode_status_id", to: "assets#refresh_active_encode_status", as: "refresh_active_encode_status"

    post "/asset_files/:asset_id/check_fixity", to: "assets#check_fixity", as: "check_fixity"
    get "/fixity_report", to: "assets#fixity_report", as: "fixity_report"
    get "/storage_report", to: "storage_report#index", as: "storage_report"
    get "/orphan_report", to: "orphan_report#index", as: "orphan_report"

    resources :oral_history_requests, only: [:index, :show] do
      member do
        post "respond"
      end
      collection do
        post "report", to: "oral_history_requests#report"
      end
    end

    get "/batch_create", to: "batch_create#new", as: "batch_create" # step 1
    post "/batch_create", to: "batch_create#add_files" # step 2
    post "/batch_create/finish", to: "batch_create#create" # step 3, create and redirect

    resources :digitization_queue_items do
      member do
        post :add_comment
      end
    end

    delete  "digitization_queue_items/:id/delete_comment/:comment_id",
      to: "digitization_queue_items#delete_comment",
      as: "delete_digitization_queue_item_comment"


    #Cart:
    resources :cart_items, param: :work_friendlier_id, only: [:index, :update, :destroy] do
      collection do
        delete 'clear'
        post 'report'
      end
    end

    post "cart_items/update_multiple",
      to: "cart_items#update_multiple",
      as: "update_multiple_cart_items",
      format: "json"

    resources :interviewer_profiles, except: [:show]
    resources :interviewee_biographies, except: [:show]


    # These 'sub-apps' are for admin-use only, but since they are sub-apps
    # aren't protected by the AdminController. We have Rails routing only
    # provide the routes if the user is allowed to see the admin pages.
    constraints CanAccessStaffFunctionsConstraint do
      mount Resque::Server, at: '/queues'

      mount Kithe::AssetUploader.upload_endpoint(:cache) => "/direct_upload", as: :direct_app_upload

      if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
        mount Shrine.uppy_s3_multipart(:cache) => "/s3"
      end
    end
  end

  # We can't put browse-everything in the routing namespace, cause it breaks
  # browse-everything, alas. We'll still make it route as if it were, and
  # add a routing constraint to protect to users allowed to see the admin pages.
  constraints CanAccessStaffFunctionsConstraint do
    mount BrowseEverything::Engine => '/admin/browse'

    # Don't know if we really need qa to be limited to logged-in users, but
    # that's the only place we use it, so let's limit to avoid anyone DOSing
    # us with it or whatever.
    #
    # And we mount it as '/authorities' rather than '/qa' that the installer
    # wanted, to match sufia/hyrax and be less weird.
    mount Qa::Engine => '/authorities'
  end


  # Tell Rails polymorphic routing to assume :admin namespace for works,
  # so we can just do `url_for @work` and get /admin/works.
  #
  # May not actually be a good idea? What will we do when we add non-admin show?
  resolve("Work") do |work, options|
    [:admin, work, options]
  end
  resolve("Asset") do |asset, options|
    [:admin, asset, options]
  end
  resolve("Collection") do |collection, options|
    [:admin, collection, options]
  end

  #Static pages
  %w(about contact faq policy api_docs).each do |page_label|
    get page_label, controller: 'static', action: page_label, as: page_label
  end

  get "/rights/:id(/:work_id)", to: "rights_term_display#show", as: :rights_term
end
