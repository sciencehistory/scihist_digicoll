Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


  # TODO, need to restrict to probably just logged in users, at least.
  mount Kithe::AssetUploader.upload_endpoint(:cache) => "/direct_upload"

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
