class ApplicationController < ActionController::Base
  after_action :track_action
  
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  protect_from_forgery with: :exception

  helper_method :site_settings, :navbar_items

  protected

  def track_action
    ahoy.track "Viewed", request.path_parameters
  end
  
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
