class ApplicationController < ActionController::Base
  include CacheableSettings
  before_action :set_time_zone
  after_action :track_action

  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery with: :exception

  helper_method :navbar_items

  protected

  def track_action
    ahoy.track "Viewed", request.path_parameters
  end

  private

  def set_time_zone
    Time.zone = CacheableSettings.site_info[:time_zone] || "UTC"
  end

  def navbar_items
    @navbar_items ||= CacheableSettings.navbar_items
  end

  def refresh_settings
    CacheableSettings.refresh_site_info
  end

  def refresh_pages
    CacheableSettings.refresh_navbar_items
  end
end
