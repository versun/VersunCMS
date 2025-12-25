class ArchiveSourceUrlJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for rate limiting
  # 增加重试次数和等待时间，因为 Internet Archive 可能需要较长时间
  retry_on StandardError, wait: :polynomially_longer, attempts: 8

  # 对于网络超时，单独处理
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 30.seconds, attempts: 5

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article
    return if article.source_url.blank?
    return if article.source_archive_url.present?

    # 验证 URL 格式
    unless valid_url?(article.source_url)
      Rails.event.notify "archive_source_url_job.invalid_url",
        level: "warn",
        component: "ArchiveSourceUrlJob",
        article_id: article.id,
        source_url: article.source_url
      return
    end

    service = InternetArchiveService.new
    result = service.save_url(article.source_url)

    if result[:success] && result[:archived_url].present?
      # Update without triggering callbacks to avoid infinite loop
      article.update_column(:source_archive_url, result[:archived_url])

      Rails.event.notify "archive_source_url_job.archived",
        level: "info",
        component: "ArchiveSourceUrlJob",
        article_id: article.id,
        archived_url: result[:archived_url]
    else
      error_msg = result[:error] || "Unknown error"
      Rails.event.notify "archive_source_url_job.archive_failed",
        level: "warn",
        component: "ArchiveSourceUrlJob",
        article_id: article.id,
        error_message: error_msg

      # Re-raise to trigger retry for rate limiting errors
      if error_msg.include?("rate limit")
        raise StandardError, error_msg
      end

      # 对于其他类型的错误，如果是临时性的也重试
      if error_msg.include?("timeout") || error_msg.include?("connection")
        raise StandardError, error_msg
      end

      # 对于永久性错误（如 URL 无法访问），不重试
    end
  end

  private

  def valid_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end
