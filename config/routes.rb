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

  if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
    # TODO, auth restrictions?
    mount Shrine.uppy_s3_multipart(:cache) => "/s3"
  end

  # We'll handle show elsewhere
  resources :works, except: [:show] do
    member do
      get "members", action: :members_index, as: "members_for"
    end
  end

  # Note "assets" is Rails reserved word, oops.
  get "/works/:parent_id/ingest", to: "assets#display_attach_form", as: "asset_ingest"
  post "/works/:parent_id/ingest", to: "assets#attach_files"
  get "/asset_files/:id/show", to: "assets#show", as: "show_asset"


end
