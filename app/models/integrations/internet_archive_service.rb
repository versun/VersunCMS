require "net/http"
require "uri"

module Integrations
  class InternetArchiveService
    include ContentBuilder

    SAVE_API_URL = "https://web.archive.org/save"

    def initialize
      @settings = Crosspost.internet_archive
    end

    def verify(settings)
      # Internet Archive 不需要特殊的验证，只需要检查是否启用
      # 可以通过尝试保存一个测试 URL 来验证，但通常不需要
      { success: true }
    end

    def post(article)
      return unless @settings&.enabled?

      # 构建文章 URL
      article_url = build_post_url(article.slug)

      begin
        # 使用 Wayback Machine Save API 保存 URL
        archived_url = save_to_wayback(article_url)

        if archived_url
          ActivityLog.create!(
            action: "completed",
            target: "crosspost",
            level: :info,
            description: "Successfully archived article #{article.title} to Internet Archive"
          )

          archived_url
        else
          ActivityLog.create!(
            action: "failed",
            target: "crosspost",
            level: :error,
            description: "Failed to archive article #{article.title} to Internet Archive"
          )
          nil
        end
      rescue => e
        ActivityLog.create!(
          action: "failed",
          target: "crosspost",
          level: :error,
          description: "Failed to archive article #{article.title} to Internet Archive: #{e.message}"
        )
        nil
      end
    end

    private

    def save_to_wayback(url)
      # 使用 Wayback Machine Save API
      # 方法：使用 GET 请求到 https://web.archive.org/save/<url>
      # 这会触发存档过程，但不会立即返回存档 URL
      # 我们需要稍后检查存档状态

      encoded_url = URI.encode_www_form_component(url)
      save_uri = URI("https://web.archive.org/save/#{encoded_url}")

      http = Net::HTTP.new(save_uri.host, save_uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 30

      request = Net::HTTP::Get.new(save_uri)
      request["User-Agent"] = "VersunCMS/1.0"

      response = http.request(request)

      # Wayback Machine 的保存请求通常是异步的
      # 即使返回成功，存档也可能需要一些时间
      if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection) || response.code == "200"
        # 等待一小段时间，然后检查存档状态
        sleep(2)

        # 检查存档 URL
        archived_url = check_archived_url(url)

        if archived_url
          archived_url
        else
          # 如果还没有存档，返回一个待处理的 URL
          # 用户稍后可以手动检查
          Rails.logger.info "Internet Archive save request submitted for #{url}, but archive not yet available"
          # 返回一个检查 URL，用户可以稍后访问
          "https://web.archive.org/web/*/#{url}"
        end
      elsif response.code == "429"
        # 速率限制
        Rails.logger.warn "Internet Archive rate limit exceeded"
        ActivityLog.create!(
          action: "rate_limited",
          target: "internet_archive_api",
          level: :warning,
          description: "Internet Archive rate limit exceeded"
        )
        nil
      else
        Rails.logger.error "Failed to save to Wayback Machine: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "Error saving to Wayback Machine: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end

    # 检查 URL 是否已被存档，并返回存档 URL
    def check_archived_url(url)
      # 使用 Wayback Machine 的 available API 检查
      check_uri = URI("https://archive.org/wayback/available")
      check_uri.query = URI.encode_www_form(url: url)

      http = Net::HTTP.new(check_uri.host, check_uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(check_uri)
      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        if data.dig("archived_snapshots", "closest", "available")
          data.dig("archived_snapshots", "closest", "url")
        else
          # 如果还没有存档，返回原始 URL（保存请求可能还在处理中）
          nil
        end
      else
        nil
      end
    rescue => e
      Rails.logger.error "Error checking archived URL: #{e.message}"
      nil
    end
  end
end
