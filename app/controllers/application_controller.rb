class ApplicationController < ActionController::Base
  include CacheableSettings
  before_action :set_time_zone
  before_action :process_redirects

  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern
  protect_from_forgery with: :exception

  helper_method :navbar_items

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

  def process_redirects
    return if request.path.start_with?("/admin") # Skip redirects for admin pages

    Redirect.enabled.find_each do |redirect|
      if redirect.match?(request.path)
        target_url = redirect.apply_to(request.path)
        next unless target_url

        status = redirect.permanent? ? :moved_permanently : :found
        redirect_to target_url, status: status
        return
      end
    end
  end
end
