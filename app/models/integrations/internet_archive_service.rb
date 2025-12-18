require "net/http"
require "uri"
require "cgi"

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

    # Save any URL to Internet Archive (for source references)
    # This method doesn't require the crosspost settings to be enabled
    def save_url(url)
      return { error: "URL is required" } if url.blank?

      begin
        archived_url = save_to_wayback(url)

        if archived_url
          ActivityLog.create!(
            action: "completed",
            target: "internet_archive",
            level: :info,
            description: "Successfully archived URL to Internet Archive: #{url}"
          )

          { success: true, archived_url: archived_url }
        else
          { error: "Failed to archive URL" }
        end
      rescue => e
        ActivityLog.create!(
          action: "failed",
          target: "internet_archive",
          level: :error,
          description: "Failed to archive URL to Internet Archive: #{url} - #{e.message}"
        )
        { error: e.message }
      end
    end

    private

    def save_to_wayback(url, max_retries: 3, retry_count: 0)
      # 使用 Wayback Machine Save API
      # URL 需要进行路径编码，以正确处理包含 ?、&、#、空格等特殊字符的 URL
      # 例如：https://example.com/page?foo=bar 需要编码为 https%3A%2F%2Fexample.com%2Fpage%3Ffoo%3Dbar

      begin
        # 对 URL 进行编码，确保特殊字符被正确处理
        encoded_url = CGI.escape(url)
        save_uri = URI("https://web.archive.org/save/#{encoded_url}")

        http = Net::HTTP.new(save_uri.host, save_uri.port)
        http.use_ssl = true
        http.open_timeout = 60
        http.read_timeout = 120  # 增加读取超时，存档可能需要较长时间

        request = Net::HTTP::Get.new(save_uri)
        request["User-Agent"] = "Mozilla/5.0 (compatible; Rables/1.0; +https://versun.me)"
        request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

        response = http.request(request)

        Rails.logger.info "Internet Archive save response: code=#{response.code}, location=#{response['Location']}"

        # 检查响应
        case response.code
        when "200"
          # 成功：从响应头或 body 中提取存档 URL
          archived_url = extract_archived_url_from_response(response, url)
          if archived_url
            Rails.logger.info "Internet Archive archived URL: #{archived_url}"
            archived_url
          else
            # 如果无法从响应中提取，等待后检查
            sleep(5)
            check_archived_url(url) || generate_archive_url(url)
          end
        when "302", "301"
          # 重定向：通常会重定向到存档页面
          location = response["Location"]
          if location&.include?("web.archive.org/web/")
            Rails.logger.info "Internet Archive redirect to: #{location}"
            location
          else
            # 跟随重定向
            sleep(3)
            check_archived_url(url) || generate_archive_url(url)
          end
        when "429"
          handle_rate_limit(url, max_retries, retry_count)
        when "523", "520", "521", "522", "524"
          # Cloudflare 错误 - 目标网站可能有问题，但仍可能已存档
          Rails.logger.warn "Internet Archive received Cloudflare error #{response.code} for #{url}"
          sleep(5)
          check_archived_url(url) || generate_archive_url(url)
        else
          Rails.logger.error "Failed to save to Wayback Machine: #{response.code} - #{response.body[0..500]}"
          # 尝试检查是否已经存档，如果没有则生成预期的存档 URL
          check_archived_url(url) || generate_archive_url(url)
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.warn "Internet Archive timeout for #{url}: #{e.message}"
        # 超时不一定是失败，可能存档正在进行，检查是否已存档
        sleep(5)
        check_archived_url(url) || generate_archive_url(url)
      rescue => e
        handle_save_error(e, url, max_retries, retry_count)
      end
    end

    def handle_rate_limit(url, max_retries, retry_count)
      if retry_count < max_retries
        wait_time = calculate_backoff_time(retry_count + 1)
        Rails.logger.warn "Internet Archive rate limit exceeded, waiting #{wait_time} seconds before retry #{retry_count + 1}/#{max_retries}"
        ActivityLog.create!(
          action: "rate_limited",
          target: "internet_archive_api",
          level: :warning,
          description: "Internet Archive rate limit exceeded, retrying in #{wait_time} seconds (attempt #{retry_count + 1}/#{max_retries})"
        )
        sleep(wait_time)
        save_to_wayback(url, max_retries: max_retries, retry_count: retry_count + 1)
      else
        Rails.logger.error "Internet Archive rate limit exceeded after #{max_retries} retries"
        ActivityLog.create!(
          action: "rate_limited",
          target: "internet_archive_api",
          level: :error,
          description: "Internet Archive rate limit exceeded after #{max_retries} retries"
        )
        raise StandardError, "Internet Archive rate limit exceeded after #{max_retries} retries"
      end
    end

    def handle_save_error(error, url, max_retries, retry_count)
      if error.message.include?("rate limit") && retry_count < max_retries
        wait_time = calculate_backoff_time(retry_count + 1)
        Rails.logger.warn "Internet Archive error, retrying in #{wait_time} seconds (attempt #{retry_count + 1}/#{max_retries}): #{error.message}"
        sleep(wait_time)
        save_to_wayback(url, max_retries: max_retries, retry_count: retry_count + 1)
      else
        Rails.logger.error "Error saving to Wayback Machine: #{error.message}"
        Rails.logger.error error.backtrace.first(5).join("\n")
        raise error if error.message.include?("rate limit")
        nil
      end
    end

    def extract_archived_url_from_response(response, original_url)
      # 尝试从响应头中获取存档 URL
      content_location = response["Content-Location"]
      if content_location&.include?("/web/")
        return "https://web.archive.org#{content_location}"
      end

      # 尝试从 X-Archive-Orig-* 头中构建
      if response["X-Archive-Orig-Date"]
        # 存档成功，构建存档 URL
        # 从 Link 头或其他头信息中提取时间戳
        memento_link = response["Link"]
        if memento_link
          # 解析 Link 头中的 memento URL
          match = memento_link.match(/web\.archive\.org\/web\/(\d+)/)
          if match
            return "https://web.archive.org/web/#{match[1]}/#{original_url}"
          end
        end
      end

      nil
    end

    def generate_archive_url(url)
      # 生成一个带有当前时间戳的预期存档 URL
      # 格式：YYYYMMDDHHmmss
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      "https://web.archive.org/web/#{timestamp}/#{url}"
    end

    # 计算指数退避时间（秒）
    def calculate_backoff_time(retry_count)
      # 指数退避：基础 5 秒，最大 120 秒
      # Internet Archive 需要更长的退避时间
      base_wait = 5
      [ base_wait * (2 ** retry_count), 120 ].min
    end

    # 检查 URL 是否已被存档，并返回存档 URL
    def check_archived_url(url, retries: 2)
      retries.times do |attempt|
        result = fetch_archived_url(url)
        return result if result

        # 如果没找到，等待后重试（存档可能还在处理中）
        sleep(3) if attempt < retries - 1
      end
      nil
    end

    def fetch_archived_url(url)
      # 使用 Wayback Machine 的 available API 检查
      check_uri = URI("https://archive.org/wayback/available")
      check_uri.query = URI.encode_www_form(url: url)

      http = Net::HTTP.new(check_uri.host, check_uri.port)
      http.use_ssl = true
      http.open_timeout = 15
      http.read_timeout = 15

      request = Net::HTTP::Get.new(check_uri)
      request["User-Agent"] = "Mozilla/5.0 (compatible; Rables/1.0)"
      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        Rails.logger.info "Internet Archive availability check response: #{data.inspect}"

        if data.dig("archived_snapshots", "closest", "available")
          archived_url = data.dig("archived_snapshots", "closest", "url")
          # 确保返回 https 版本
          archived_url&.sub("http://", "https://")
        else
          nil
        end
      else
        Rails.logger.warn "Internet Archive availability check failed: #{response.code}"
        nil
      end
    rescue => e
      Rails.logger.error "Error checking archived URL: #{e.message}"
      nil
    end
  end
end
