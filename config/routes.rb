require 'resque/server'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # temporarily, as we build out app, this is the part we have working...
  root to: "works#index"

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

  # Admin page for work management, we'll handle public view elsewhere
  resources :works do
    member do
      match "members_reorder", via: [:put, :get], as: "reorder_members_for"
    end
  end

  # Note "assets" is Rails reserved word for routing, oops.
  resources :assets, path: "asset_files", only: [:show, :destroy]


  get "/works/:parent_id/ingest", to: "assets#display_attach_form", as: "asset_ingest"
  post "/works/:parent_id/ingest", to: "assets#attach_files"
  #get "/asset_files/:id/show", to: "assets#show", as: "show_asset"


end
