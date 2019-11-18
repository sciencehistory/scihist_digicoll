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
  get "/collections/:collection_id", to: "collection_show#index", as: :collection
  get "collections/:collection_id/range_limit" => "collection_show#range_limit"
  get "collections/:collection_id/facet" => "collection_show#facet"

  get "focus/:slug", to: "featured_topic#index", as: :featured_topic
  get "focus/:slug/range_limit" => "featured_topic#range_limit"
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
        # not sure how to do this implicitly.
        # delete :delete_comment
      end
    end

    # TODO: investigate whether this could live in the
    # resources :digitization_queue_items > member do block.
    # Something like delete :delete_comment
    # but with an additional :comment_id parameter.
    # For now, just do the obvious:
    delete  "digitization_queue_items/:id/delete_comment/:comment_id",
      to: "digitization_queue_items#delete_comment",
      as: "delete_comment"


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
