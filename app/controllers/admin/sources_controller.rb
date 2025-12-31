require "net/http"
require "json"
require "nokogiri"

class Admin::SourcesController < Admin::BaseController
  # POST /admin/sources/fetch_twitter
  # Fetch tweet content for source reference
  def fetch_twitter
    url = params[:url]

    if url.blank?
      render json: { error: "URL is required" }, status: :unprocessable_entity
      return
    end

    unless twitter_url?(url)
      render json: { error: "Not a valid Twitter/X URL" }, status: :unprocessable_entity
      return
    end

    result = fetch_twitter_content(url)

    if result
      render json: {
        success: true,
        author: result[:author],
        content: result[:content]
      }
    else
      render json: { error: "Failed to fetch tweet content" }, status: :service_unavailable
    end
  end

  private

  def twitter_url?(url)
    uri = URI.parse(url)
    host = uri.host.to_s.downcase
    %w[twitter.com www.twitter.com x.com www.x.com].include?(host)
  rescue URI::InvalidURIError
    false
  end

  def fetch_twitter_content(tweet_url)
    oembed_url = "https://publish.twitter.com/oembed"
    uri = URI(oembed_url)
    uri.query = URI.encode_www_form(url: tweet_url, omit_script: true, dnt: true)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      html = data["html"]

      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      text = doc.css("p").map(&:text).join(" ").strip

      author_name = data["author_name"]
      content = text.presence || ""
      content = content[0, 250] if content.length > 250

      { author: author_name, content: content }
    else
      nil
    end
  rescue => e
    Rails.logger.error "Failed to fetch twitter content: #{e.message}"
    nil
  end
end
