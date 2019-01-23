require 'resque/server'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # temporarily, as we build out app, this is the part we have working...
  root to: "works#index"

  namespace :admin do
    # Admin page for work management, we'll handle public view elsewhere
    resources :works do
      member do
        match "members_reorder", via: [:put, :get], as: "reorder_members_for"
      end
    end

    get "/works/:parent_id/ingest", to: "assets#display_attach_form", as: "asset_ingest"
    post "/works/:parent_id/ingest", to: "assets#attach_files"


    # Note "assets" is Rails reserved word for routing, oops. So we use
    # asset_files.
    resources :assets, path: "asset_files", except: [:new, :create]
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

  # Should be protecting to just logged in users?
  mount BrowseEverything::Engine => '/browse'

  # TODO, need to restrict to probably just logged in users, at least.
  mount Kithe::AssetUploader.upload_endpoint(:cache) => "/direct_upload"

  # TODO, need to restrict to probably just logged in users, at least.
  if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
    mount Shrine.uppy_s3_multipart(:cache) => "/s3"
  end

  # TODO restrictions, URL
  mount Resque::Server, at: 'admin/queues'

  if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
    # TODO, auth restrictions?
    mount Shrine.uppy_s3_multipart(:cache) => "/s3"
  end

  resources :collections, except: [:show]




end
