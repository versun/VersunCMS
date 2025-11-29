Rails.application.routes.draw do
  # Defines the root path route ("/")
  root "articles#index"
  get "/analytics" => "analytics#index"

  # User authentication and management
  resources :users
  resource :session
  resources :passwords
  resource :setup, only: [ :show, :create ], controller: "setup"

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
        post :fetch_comments
      end
    end

    resources :pages do
      member do
        patch :reorder
      end
    end

    resources :tags

    # Comment management
    resources :comments do
      member do
        patch :approve
        delete :reject
      end
    end

    # System management
    resource :setting, only: [ :edit, :update ]
    resources :static_files, only: [ :index, :create, :destroy ]
    resources :redirects

    resource :newsletter, only: [ :show, :update ], controller: "newsletter" do
      collection do
        post :verify
      end
    end
    resources :migrates, only: [ :index, :create ]
    resource :backups, only: [ :show, :update, :create ]

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

  # Public comment submission
  resources :comments, only: [ :create ]

  # Static files public access
  get "/static/*filename", to: "static_files#show", as: :static_file, format: false

  # Health check and feeds
  get "up" => "rails/health#show", as: :rails_health_check
  get "/rss" => redirect("/feed")
  get "/rss.xml" => redirect("/feed")
  get "/feed.xml" => redirect("/feed")
  get "/feed" => "articles#index", format: "rss"
  get "/sitemap.xml" => "sitemap#index", format: "xml", as: :sitemap

  # Public pages routes - for viewing published pages
  resources :pages, only: [ :show ], param: :slug

  # Public tags routes - for browsing tags and filtering articles
  resources :tags, only: [ :index, :show ], param: :slug

  # Public article routes (must be last to avoid conflicts)
  scope path: Rails.application.config.x.article_route_prefix do
    get "/" => "articles#index", as: :articles
    get "/:slug" => "articles#show", as: :article
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
