class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery with: :exception

  helper_method :site_settings, :navbar_items

  private

  def site_settings
    @site_settings ||= Setting.site_info
  end

  def navbar_items
    @navbar_items ||= Setting.navbar_items
  end

  def refresh_settings
    Setting.refresh_all
  end

  def refresh_pages
    Setting.refresh_navbar_items
  end
end
