Rails.application.routes.draw do
  # Defines the root path route ("/")
  root "articles#index"
  get "/analytics" => "analytics#index"

  # User authentication and management
  resources :users
  resource :session
  resources :passwords
  resource :setup, only: [ :show, :create ], controller: "setup"

  # Newsletter subscriptions
  resources :subscriptions, only: [ :index, :create ]
  get "/confirm", to: "subscriptions#confirm", as: :confirm_subscription
  get "/unsubscribe", to: "subscriptions#unsubscribe", as: :unsubscribe

  # Admin namespace - 统一所有后台管理功能
  namespace :admin do
    # Admin root now points to articles index
    get "/", to: "articles#index", as: :root

    # Content management
    resources :articles, path: "posts" do
      collection do
        get :drafts
        get :scheduled
        post :batch_destroy
        post :batch_publish
        post :batch_unpublish
        post :batch_add_tags
        post :batch_crosspost
        post :batch_newsletter
      end
      member do
        patch :publish
        patch :unpublish
        post :fetch_comments
      end
    end

    resources :pages do
      collection do
        post :batch_destroy
        post :batch_publish
        post :batch_unpublish
      end
      member do
        patch :reorder
      end
    end

    resources :tags do
      collection do
        post :batch_destroy
      end
    end

    # Comment management
    resources :comments do
      collection do
        post :batch_destroy
        post :batch_approve
        post :batch_reject
      end
      member do
        patch :approve
        patch :reject
      end
    end

    # System management
    resource :setting, only: [ :edit, :update ]
    resource :generate, only: [ :edit, :update ], controller: "generates"
    resources :static_files, only: [ :index, :create, :destroy ]
    resources :redirects

    resource :newsletter, only: [ :show, :update ], controller: "newsletter" do
      collection do
        post :verify
      end
    end
    resources :subscribers, only: [ :index, :destroy ] do
      collection do
        post :batch_create
      end
    end
    resources :migrates, only: [ :index, :create ]

    # 导出文件下载
    get "downloads/:filename", to: "downloads#show", as: :download, constraints: { filename: /[^\/]+/ }
    resources :crossposts, only: [ :index, :update ] do
      member do
        post :verify
      end
    end

    # Activity logs
    resources :activities, only: [ :index ]

    # Static site generation
    post "generate_static", to: "static_generation#create", as: :generate_static

    # Jobs and system monitoring
    mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
  end

  # Public comment submission
  resources :comments, only: [ :create ]
  
  # Handle CORS preflight requests for comments
  match '/comments', to: 'comments#options', via: :options

  # Static files public access
  get "/static/*filename", to: "static_files#show", as: :static_file, format: false

  # API endpoints
  namespace :api do
    get "twitter/oembed", to: "twitter#oembed"
  end

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
