require 'resque/server'

Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  class LoggedInConstraint
    def self.matches?(request)
      current_user = request.env['warden'].user
      !!current_user
    end
  end



  # Oral History legacy redirects, come first in routes file so they'll match first
  # for requests to old oral history host oh.sciencehistory.org
  OH_LEGACY_REDIRECTS ||= YAML.load_file(Rails.root + "config/oral_history_legacy_redirects.yml").freeze
  constraints host: ScihistDigicoll::Env.lookup!(:oral_history_legacy_host) do
    # OH home page, send to new OH collection page
    root as: false, to: redirect { "#{ScihistDigicoll::Env.lookup!("app_url_base")}/collections/#{ScihistDigicoll::Env.lookup!("oral_history_collection_id")}"  }


    # Links to search results in legacy OH site should redirct to search of OH collection.
    # We only support basic query term, not fielded search or facets.
    get "search/site/*query", to: redirect { |path_params, req|
      "#{ScihistDigicoll::Env.lookup!("app_url_base")}/collections/#{ScihistDigicoll::Env.lookup!("oral_history_collection_id")}?q=#{path_params[:query]}"
    }
    get "search/oh/*query", to: redirect { |path_params, req|
      "#{ScihistDigicoll::Env.lookup!("app_url_base")}/collections/#{ScihistDigicoll::Env.lookup!("oral_history_collection_id")}?q=#{path_params[:query]}"
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
  devise_for :users, skip: [:session, :registration]
  devise_scope :user do
    get 'login', to: 'devise/sessions#new', as: :new_user_session
    post 'login', to: 'devise/sessions#create', as: :user_session
    delete 'logout', to: 'devise/sessions#destroy', as: :destroy_user_session
  end

  # Dynamic robots.txt
  # this will fall through to ./views/application/robots.txt.erb, no need for an action method
  get 'robots.txt', to: "application#robots.txt", format: "text"

  # On-demand derivatives
  constraints(derivative_type: Regexp.union(OnDemandDerivative.derivative_type_definitions.keys.collect(&:to_s))) do
    get "works/:id/:derivative_type", to: "on_demand_derivatives#on_demand_status", as: :on_demand_derivative_status
  end

  get "works/:work_friendlier_id/request_oral_history_access", to: "oral_history_access_requests#new", as: 'request_oral_history_access_form'
  post "request_oral_history_access", to: "oral_history_access_requests#create", as: 'request_oral_history_access'

  # public-facing routes
  resources :works, only: [:show]

  # JSON info for scihist_viewer image viewer
  get '/works/:id/viewer_images_info' => 'works#viewer_images_info',
    defaults: {format: "json"},
    format: false,
    as: :viewer_images_info

  # Make the viewer  URL lead to ordinary show page, so JS can pick it up and launch viewer.
  get '/works/:id/viewer/:viewer_member_id(.:format)' => 'works#show', as: :viewer


  get '/collections', to: "collections_list#index", as: :collections

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

  if ScihistDigicoll::Env.lookup(:oral_history_collection_id)
    constraints(collection_id: ScihistDigicoll::Env.lookup(:oral_history_collection_id)) do
      concerns :collection_showable, controller: "collection_show_controllers/oral_history_collection"
    end
  end

  # and our default collection show page routing
  concerns :collection_showable


  # and the special "featured topics" or "focuses" that appear like collections
  # but are actually formed from canned searches.
  get "focus/:slug", to: "featured_topic#index", as: :featured_topic
  get "focus/:slug/range_limit" => "featured_topic#range_limit"
  get "focus/:slug/range_limit_panel" => "featured_topic#range_limit_panel"
  get "focus/:slug/facet" => "featured_topic#facet"


  # download_path(asset)
  # download_url(asset)
  get "downloads/:asset_id", to: "downloads#original", as: :download
  # download_derivative_path(asset, "thumb_small")
  # download_derivative_url(asset, "thumb_small")
  get "downloads/:asset_id/:derivative_key", to: "downloads#derivative", as: :download_derivative

  ##
  # Blacklight-generated routes, that were then modified a bit by us to take
  # out stuff we're not using.
  #

      # Route RSS and atom search results to a 404
      # until we decide to implement them.
      # Practically speaking, this only affects bots).
      get 'catalog.rss',  to: proc { [404, {}, ['']] }
      get 'catalog.atom', to: proc { [404, {}, ['']] }
      get 'catalog.json', to: proc { [404, {}, ['']] }

      # TODO: Can we get away without actuallymounting Blacklight, just using the CatalogController?
      # mount Blacklight::Engine => '/'
      concern :searchable, Blacklight::Routes::Searchable.new
      resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
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
  ##
  # End Blacklight-generated routes
  ##

  # Routes will even only _show up_ to logged in users, this applies
  # to internal rack apps we're mounting here too, like shrine upload endpoints,
  # is one reason to use a constraint.
  namespace :admin do
    root to: "works#index"

    resources :users, except: [:destroy, :show] do
      member do
        post "send_password_reset"
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
      end
    end

    get "/works/:parent_id/ingest", to: "assets#display_attach_form", as: "asset_ingest"
    post "/works/:parent_id/ingest", to: "assets#attach_files"

    resources :collections, except: [:show]

    # Note "assets" is Rails reserved word for routing, oops. So we use
    # asset_files.
    resources :assets, path: "asset_files", except: [:new, :create] do
      member do
        put "convert_to_child_work"
      end
    end

    post "/asset_files/:asset_id/check_fixity", to: "assets#check_fixity", as: "check_fixity"
    get "/fixity_report", to: "assets#fixity_report", as: "fixity_report"
    get "/storage_report", to: "storage_report#index", as: "storage_report"

    resources :oral_history_access_requests, only: [:index, :show] do
      member do
        post "respond"
      end
      collection do
        post "report", to: "oral_history_access_requests#report"
      end
    end

    get "/batch_create", to: "batch_create#new", as: "batch_create" # step 1
    post "/batch_create", to: "batch_create#add_files" # step 2
    post "/batch_create/finish", to: "batch_create#create" # step 3, create and redirect

    resources :digitization_queue_items, except: [:index, :create, :new, :destroy] do
      collection do
        get "collecting_areas"

        # index, new and create need a /$collecting_area on them.
        constraints(proc {|params, req|
            Admin::DigitizationQueueItem::COLLECTING_AREAS.include?(params[:collecting_area])
        }) do
          get ":collecting_area", to: "digitization_queue_items#index", as: ""
          post ":collecting_area", to: "digitization_queue_items#create", as: nil
          get ":collecting_area/new", to: "digitization_queue_items#new", as: "new"
        end
      end
      member do
        post :add_comment
      end
    end

    resources :r_and_r_items do
      member do
        post :add_comment
      end
    end

    delete  "digitization_queue_items/:id/delete_comment/:comment_id",
      to: "digitization_queue_items#delete_comment",
      as: "delete_digitization_queue_item_comment"

    delete  "r_and_r_items/:id/delete_comment/:comment_id",
      to: "r_and_r_items#delete_comment",
      as: "delete_r_and_r_comment"

    resources :cart_items, param: :work_friendlier_id, only: [:index, :update, :destroy] do
      collection do
        delete 'clear'
      end
    end

    resources :interviewer_profiles, except: [:show]
    resources :interviewee_biographies, except: [:show]


    # These 'sub-apps' are for admin-use only, but since they are sub-apps
    # aren't protected by the AdminController. We have Rails routing only
    # provide the routes if there is a logged-in user.
    constraints LoggedInConstraint do
      mount Resque::Server, at: '/queues'

      mount Kithe::AssetUploader.upload_endpoint(:cache) => "/direct_upload", as: :direct_app_upload

      if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
        mount Shrine.uppy_s3_multipart(:cache) => "/s3"
      end
    end
  end

  # We can't put browse-everything in the routing namespace, cause it breaks
  # browse-everything, alas. We'll still make it route as if it were, and
  # add a routing constraint to protect to just logged in users.
  constraints LoggedInConstraint do
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
  %w(about contact faq policy).each do |page_label|
    get page_label, controller: 'static', action: page_label, as: page_label
  end
end
