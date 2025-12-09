class ApplicationController < ActionController::Base
  include CacheableSettings
  before_action :set_time_zone
  before_action :redirect_to_setup_if_needed
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

  def redirect_to_setup_if_needed
    # Skip if we're already on the setup page or dealing with assets
    return if controller_name == "setup" || request.path.start_with?("/assets", "/rails/active_storage")

    # Redirect to setup if setup is incomplete
    if Setting.setup_incomplete?
      redirect_to setup_path unless request.path == setup_path
    end
  end

  def process_redirects
    return if request.path.start_with?("/admin") # Skip redirects for admin pages

    # Use all redirects and filter by enabled? method to handle string/boolean values
    Redirect.all.find_each do |redirect|
      next unless redirect.enabled? # Use the method instead of scope for better compatibility
      
      if redirect.match?(request.path)
        target_url = redirect.apply_to(request.path)
        next unless target_url

        Rails.logger.info "Redirect: #{request.path} -> #{target_url} (#{redirect.permanent? ? '301' : '302'})"
        status = redirect.permanent? ? :moved_permanently : :found
        redirect_to target_url, status: status
        return
      end
    end
  end
end
