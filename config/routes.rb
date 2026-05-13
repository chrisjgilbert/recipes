Rails.application.routes.draw do
  get  "login",  to: "sessions#new", as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resources :recipes do
    collection do
      post :import, to: "recipes/imports#create", as: :import
      post "import/image", to: "recipes/imports#create_from_image", as: :import_image
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "recipes#index"
end
