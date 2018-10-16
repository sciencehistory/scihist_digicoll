Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


  # We'll handle show elsewhere
  resources :works, except: [:show]

end
