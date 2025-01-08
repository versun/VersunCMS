Rails.application.routes.draw do
  # Defines the root path route ("/")
  root "articles#index"
  resources :users
  resource :session
  resources :passwords
  resource :setting, only: [ :edit, :update ]
  # get "admin" => "sessions#new"

  namespace :tools do
    resources :export, only: [ :index, :create ]
    resources :import, only: [ :index ] do
      collection do
        post :from_db
        post :from_wordpress
      end
    end
    resources :backup, only: [ :index, :create ] do
      collection do
        post :perform_backup
        get :last_backup_status
        get :list_backups
        post :restore
      end
    end
  end

  resources :crossposts, only: [ :index, :update ] do
    member do
      post :verify
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "/rss" => redirect("/blog.rss")
  get "/feed" => redirect("/blog.rss")

  get "/admin" => "admin#posts"
  get "/admin/posts" => "admin#posts"
  get "admin/posts/new", to: "articles#new"
  get "/admin/pages" => "admin#pages"
  get "admin/pages/new", to: "articles#new"

  get "/blog" => "articles#index", as: :articles
  # get "/blog/new" => "articles#new", as: :new_article
  get "/blog/:slug" => "articles#show", as: :article
  get "/blog/:slug/edit" => "articles#edit", as: :edit_article
  post "/blog" => "articles#create", as: :create_article
  patch "/blog/:slug" => "articles#update", as: :update_article
  delete "/blog/:slug" => "articles#destroy", as: :destroy_article
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Static files routes
  get "/:file_name", to: "settings#static_file",
    constraints: { file_name: /robots\.txt|humans\.txt|security\.txt/ }
end
