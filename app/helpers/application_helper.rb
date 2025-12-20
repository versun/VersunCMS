require "uri"

module ApplicationHelper
  def site_settings
    CacheableSettings.site_info
  end

  def rails_api_url
    # Get Rails API URL from environment variable or use site URL as fallback
    api_url = ENV.fetch("RAILS_API_URL", nil)
    if api_url.present?
      api_url = api_url.chomp("/")
      api_url = "https://#{api_url}" unless api_url.match?(%r{^https?://})
      # In development, force HTTP for localhost to avoid SSL connection errors
      if Rails.env.development? && api_url.include?("localhost") && api_url.start_with?("https://")
        api_url = api_url.sub("https://", "http://")
      end
      return api_url
    end

    # Fallback to site URL if no API URL is configured
    site_url = site_settings[:url].presence || "http://localhost:3000"
    site_url = site_url.chomp("/")

    # Ensure URL has a protocol
    site_url = "http://#{site_url}" unless site_url.match?(%r{^https?://})

    # In development, force HTTP for localhost to avoid SSL connection errors
    # This prevents "server unexpectedly closed connection" errors when
    # site_settings[:url] is configured with HTTPS but local server only supports HTTP
    if Rails.env.development?
      uri = URI.parse(site_url)
      if uri.host == "localhost" || uri.host == "127.0.0.1" || uri.host&.start_with?("127.")
        site_url = site_url.sub(/^https:/, "http:")
      end
    end

    site_url
  end
end
