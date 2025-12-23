class StaticRenderController < ActionController::Base
  include ApplicationHelper
  include ArticlesHelper
  include PagesHelper

  helper_method :site_settings, :navbar_items, :authenticated?, :flash, :rails_api_url

  def site_settings
    CacheableSettings.site_info
  end

  def navbar_items
    CacheableSettings.navbar_items
  end

  def authenticated?
    false
  end

  def flash
    {}
  end
end
