module CacheableSettings
  extend ActiveSupport::Concern

  def self.site_info
    Rails.cache.fetch("site_info", expires_in: 1.hour) do
      setting = Setting.first
      return {} unless setting

      {
        title: setting.title,
        description: setting.description,
        author: setting.author,
        url: setting.url,
        head_code: setting.head_code,
        footer: setting.footer,
        custom_css: setting.custom_css,
        social_links: setting.social_links,
        tool_code: setting.tool_code,
        giscus: setting.giscus,
        time_zone: setting.time_zone || "UTC"
      }
    end
  end

  def self.navbar_items
    Rails.cache.fetch("navbar_items", expires_in: 1.hour) do
      Page.published.order(page_order: :desc).select(:id, :title, :slug, :redirect_url)
    end
  end

  def self.refresh_site_info
    Rails.cache.delete("site_info")
  end

  def self.refresh_navbar_items
    Rails.cache.delete("navbar_items")
  end

  def self.refresh_all
    refresh_site_info
    refresh_navbar_items
  end
end
