require "net/http"
require "uri"

# Internet Archive S3-like API Service
# Uploads HTML files directly to archive.org Items
# API docs: https://archive.org/developers/ias3.html
class InternetArchiveService
  S3_API_URL = "https://s3.us.archive.org"

  class UploadError < StandardError; end

  def initialize
    @settings = ArchiveSetting.instance
  end

  def configured?
    @settings.ia_configured?
  end

  # Upload an HTML file to Internet Archive
  # Returns the archive.org item URL on success
  def upload_html(file_path, item_name:, title: nil)
    raise UploadError, "Internet Archive credentials not configured" unless configured?
    raise UploadError, "File not found: #{file_path}" unless File.exist?(file_path)

    filename = File.basename(file_path)
    content = File.read(file_path)

    upload_to_s3(
      item_name: item_name,
      filename: filename,
      content: content,
      title: title || filename
    )
  end

  # Verify credentials by attempting a PUT request to a test item
  # GET requests to the S3 root endpoint don't validate credentials
  def verify
    return { error: "Internet Archive credentials not configured" } unless configured?

    # Use PUT request to verify credentials - this actually validates auth
    # Use a unique test item name that won't conflict with real items
    test_item = "rables-auth-verify-#{SecureRandom.hex(8)}"
    uri = URI("#{S3_API_URL}/#{test_item}/_verify_credentials.txt")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Put.new(uri)
    request["Authorization"] = "LOW #{@settings.ia_access_key}:#{@settings.ia_secret_key}"
    request["Content-Type"] = "text/plain"
    request["x-archive-auto-make-bucket"] = "1"
    request["x-archive-meta-collection"] = "test_collection"
    request["x-archive-queue-derive"] = "0"
    request.body = "verify"

    response = http.request(request)
    body = response.body.to_s

    # Check response body for invalid credential indicators
    if body.include?("InvalidAccessKeyId")
      { error: "Access Key 无效" }
    elsif body.include?("SignatureDoesNotMatch")
      { error: "Secret Key 无效" }
    elsif response.code == "200" || response.code == "201"
      # Credentials are valid - item was created
      { success: true }
    elsif body.include?("BucketAlreadyExists") || body.include?("BucketAlreadyOwnedByYou")
      # Bucket exists means credentials are valid (auth passed, just name conflict)
      { success: true }
    elsif body.include?("AccessDenied")
      # AccessDenied without invalid key errors means credentials are valid
      # but account may have restrictions
      { success: true }
    else
      { error: "验证失败 (#{response.code}): #{body.truncate(100)}" }
    end
  rescue => e
    { error: e.message }
  end

  private

  def upload_to_s3(item_name:, filename:, content:, title:, max_retries: 3, rate_limit_retries: 0)
    timeout_retries = 0

    begin
      uri = URI("#{S3_API_URL}/#{item_name}/#{filename}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 120

      request = Net::HTTP::Put.new(uri)
      request["Authorization"] = "LOW #{@settings.ia_access_key}:#{@settings.ia_secret_key}"
      request["Content-Type"] = "text/html; charset=utf-8"
      request["x-archive-auto-make-bucket"] = "1"
      request["x-archive-meta-mediatype"] = "web"
      request["x-archive-meta-collection"] = "opensource"
      request["x-archive-meta-title"] = title
      request["x-archive-queue-derive"] = "0"  # Skip derive process for HTML
      request.body = content

      response = http.request(request)

      Rails.event.notify "internet_archive_service.upload_response",
        level: "info",
        component: "InternetArchiveService",
        response_code: response.code,
        item_name: item_name,
        filename: filename

      case response.code
      when "200", "201"
        # Success - return the archive.org item URL
        item_url = "https://archive.org/details/#{item_name}"

        ActivityLog.create!(
          action: "completed",
          target: "internet_archive",
          level: :info,
          description: "Successfully uploaded to Internet Archive: #{item_name}/#{filename}"
        )

        { success: true, item_url: item_url, file_url: "https://archive.org/download/#{item_name}/#{filename}" }
      when "429"
        handle_rate_limit(rate_limit_retries, max_retries) do
          upload_to_s3(
            item_name: item_name,
            filename: filename,
            content: content,
            title: title,
            max_retries: max_retries,
            rate_limit_retries: rate_limit_retries + 1
          )
        end
      when "401", "403"
        raise UploadError, "Authentication failed. Please check your Internet Archive credentials."
      else
        raise UploadError, "Upload failed with status #{response.code}: #{response.body}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      timeout_retries += 1
      if timeout_retries <= max_retries
        sleep(5 * timeout_retries)
        retry
      end
      raise UploadError, "Upload timed out after #{max_retries} retries: #{e.message}"
    rescue UploadError
      raise
    rescue => e
      raise UploadError, "Upload error: #{e.message}"
    end
  end

  def handle_rate_limit(current_retry, max_retries, &block)
    if current_retry < max_retries
      wait_time = calculate_backoff_time(current_retry + 1)

      Rails.event.notify "internet_archive_service.rate_limit_retry",
        level: "warn",
        component: "InternetArchiveService",
        wait_time: wait_time,
        retry_count: current_retry + 1

      sleep(wait_time)
      block.call
    else
      raise UploadError, "Rate limit exceeded after #{max_retries} retries"
    end
  end

  def calculate_backoff_time(retry_count)
    # Exponential backoff: base 5 seconds, max 120 seconds
    [ 5 * (2 ** retry_count), 120 ].min
  end
end
