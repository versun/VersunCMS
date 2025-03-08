module ApplicationHelper
  def site_settings
    CacheableSettings.site_info
  end
end
