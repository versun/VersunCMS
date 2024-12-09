class SettingsService
  class << self
    def time_zone
      Rails.cache.fetch("settings:time_zone", expires_in: 1.hour) do
        Setting.first&.time_zone || "UTC"
      end
    end

    def site_info
      Rails.cache.fetch("settings:site_info", expires_in: 1.hour) do
        setting = Setting.first
        return {} unless setting

        {
          title: setting&.title,
          description: setting&.description,
          author: setting&.author,
          url: setting&.url,
          head_code: setting&.head_code,
          footer: setting&.footer,
          custom_css: setting&.custom_css,
          social_links: setting&.social_links
        }
      end
    end

    def navbar_items
      Rails.cache.fetch("settings:navbar_items", expires_in: 1.hour) do
        Article.published_pages.order(page_order: :desc).select(:id, :title, :slug)
      end
    end

    def refresh_time_zone
      Rails.cache.delete("settings:time_zone")
    end

    def refresh_site_info
      Rails.cache.delete("settings:site_info")
    end

    def refresh_navbar_items
      Rails.cache.delete("settings:navbar_items")
    end

    def refresh_all
      refresh_time_zone
      refresh_site_info
      refresh_navbar_items
    end
  end
end
