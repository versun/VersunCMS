require "nokogiri"

class LinkExtractorService
  EXCLUDED_DOMAINS = %w[
    localhost
    127.0.0.1
    example.com
  ].freeze

  def initialize(article)
    @article = article
  end

  def extract_links
    links = []

    # Extract from source_url
    links << @article.source_url if @article.source_url.present?

    # Extract from content
    links.concat(extract_from_content)

    # Filter and deduplicate
    links.uniq
         .select { |url| valid_archivable_url?(url) }
         .reject { |url| excluded_domain?(url) }
  end

  private

  def extract_from_content
    content_html = if @article.html?
      @article.html_content.to_s
    else
      @article.content&.to_s || ""
    end

    return [] if content_html.blank?

    doc = Nokogiri::HTML.fragment(content_html)
    doc.css("a[href]").map { |a| a["href"] }.compact
  end

  def valid_archivable_url?(url)
    return false if url.blank?

    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def excluded_domain?(url)
    uri = URI.parse(url)
    host = uri.host.to_s.downcase

    EXCLUDED_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
  rescue URI::InvalidURIError
    true
  end
end
