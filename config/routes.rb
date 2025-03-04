Rails.application.routes.draw do
  get "analytics/index"
  get "newsletters/index"
  get "newsletters/edit"
  get "newsletters/update"
  # Defines the root path route ("/")
  root "articles#index"
  resources :users
  resource :session
  resources :passwords

  resource :setting, only: [ :edit, :update, :destroy ] do
    collection do
      post :upload
      delete :destroy
    end
  end

  namespace :tools do
    resources :export, only: [ :index, :create ]
    resources :import, only: [ :index ] do
      collection do
        post :from_rss
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
  get "/rss" => redirect("/feed")
  get "/rss.xml" => redirect("/feed")
  get "/feed.xml" => redirect("/feed")
  get "/feed" => "articles#index", format: "rss"
  get "/sitemap.xml" => "sitemap#index", format: "xml", as: :sitemap

  get "/admin" => "admin#posts"
  get "/admin/analytics" => "analytics#index", as: "analytics"
  get "/admin/posts" => "admin#posts"
  get "/admin/posts/new", to: "articles#new"
  get "/admin/pages" => "admin#pages"
  get "/admin/pages/new", to: "pages#new"
  get "/admin/newsletters", to: "newsletters#edit", as: "newsletter"
  patch "/admin/newsletters", to: "newsletters#update", as: "update_newsletter"

  scope path: Rails.application.config.article_route_prefix do
    get "/" => "articles#index", as: :articles
    get "/:slug" => "articles#show", as: :article
    get "/:slug/edit" => "articles#edit", as: :edit_article
    post "/" => "articles#create", as: :create_article
    patch "/:slug" => "articles#update", as: :update_article
    delete "/:slug" => "articles#destroy", as: :destroy_article
  end

  resources :pages, param: :slug

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
