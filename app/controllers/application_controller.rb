class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery with: :exception
  before_action :set_pages
  before_action :load_site_settings


  def refresh_pages
    Rails.cache.delete("navbar_items")
    set_pages
  end

  def refresh_settings
    Rails.cache.delete("settings")
    load_site_settings
  end

  private
    
    def set_pages
      @navbar_items = Rails.cache.fetch("navbar_items", expires_in: 1.hour) do
        pages = Article.published_pages.order(page_order: :desc).select(:id, :title, :slug)
      end
    end

    def load_site_settings
      @site = Rails.cache.fetch("settings", expires_in: 1.hour) do
        settings = Setting.first_or_create
        Time.zone = settings.time_zone
        settings
      end
    end
end
