Rails.application.routes.draw do
  # Defines the root path route ("/")
  root "articles#index"
  get "/analytics" => "analytics#index"

  # User authentication and management
  resources :users
  resource :session
  resources :passwords

  # Admin namespace - 统一所有后台管理功能
  namespace :admin do
    # Admin root now points to articles index
    get "/", to: "articles#index", as: :root

    # Content management
    resources :articles, path: "posts" do
      collection do
        get :drafts
        get :scheduled
      end
      member do
        patch :publish
        patch :unpublish
      end
    end

    resources :pages do
      member do
        patch :reorder
      end
    end

    # System management
    resource :setting, only: [ :edit, :update, :destroy ] do
      collection do
        post :upload
        delete :destroy
      end
    end

    resource :newsletter, only: [ :show, :update ], controller: "newsletter" do
      collection do
        post :verify
      end
    end
    resources :exports, only: [ :index, :create ]
    resources :imports, only: [ :index, :create ]

    # 导出文件下载
    get "downloads/:filename", to: "downloads#show", as: :download, constraints: { filename: /[^\/]+/ }
    resources :crossposts, only: [ :index, :update ] do
      member do
        post :verify
      end
    end

    # Jobs and system monitoring
    mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
  end

  # Health check and feeds
  get "up" => "rails/health#show", as: :rails_health_check
  get "/rss" => redirect("/feed")
  get "/rss.xml" => redirect("/feed")
  get "/feed.xml" => redirect("/feed")
  get "/feed" => "articles#index", format: "rss"
  get "/sitemap.xml" => "sitemap#index", format: "xml", as: :sitemap

  # Public article and page routes
  scope path: Rails.application.config.x.article_route_prefix do
    get "/" => "articles#index", as: :articles
    get "/:slug" => "articles#show", as: :article
    get "/:slug/edit" => "articles#edit", as: :edit_article
    post "/" => "articles#create", as: :create_article
    patch "/:slug" => "articles#update", as: :update_article
    delete "/:slug" => "articles#destroy", as: :destroy_article
  end

  resources :pages, param: :slug

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
