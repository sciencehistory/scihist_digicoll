require 'resque/server'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

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

  # We'll handle show elsewhere
  resources :works, except: [:show] do
    member do
      get "members", action: :members_index, as: "members_for"
    end
  end

  # Note "assets" is Rails reserved word, oops.
  get "/asset/ingest_direct/:parent_id", to: "assets#ingest_direct_files_input", as: "ingest_direct"
  post "/asset/attach/:parent_id", to: "assets#attach_files", as: "attach_files"


end
