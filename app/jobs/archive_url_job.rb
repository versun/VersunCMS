class ArchiveUrlJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for transient errors
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 3
  retry_on StandardError, wait: ->(executions) { 2 ** executions }, attempts: 3 do |job, error|
    # Don't retry if it's a configuration error
    error.message.include?("not configured") ||
      error.message.include?("not found") ||
      error.message.include?("permission denied") ||
      error.message.include?("Authentication failed")
  end

  # Don't retry on configuration errors
  discard_on SingleFileArchiveService::SingleFileNotFoundError do |job, error|
    handle_discard(job, error)
  end

  discard_on SingleFileArchiveService::BrowserNotFoundError do |job, error|
    handle_discard(job, error)
  end

  # Don't retry on git operation errors (authentication, permissions, etc.)
  discard_on SingleFileArchiveService::GitOperationError do |job, error|
    handle_discard(job, error)
  end

  def perform(archive_item_id)
    archive_item = ArchiveItem.find_by(id: archive_item_id)
    return unless archive_item
    return if archive_item.completed?

    archive_item.update!(status: :processing)

    service = SingleFileArchiveService.new

    begin
      # Archive the URL
      result = service.archive_url(archive_item)

      # Mark as completed
      archive_item.mark_completed!(
        file_path: result[:file_path],
        file_size: result[:file_size]
      )

      service.regenerate_index!

      if result[:ia_url].present? && archive_item.article.present?
        post = archive_item.article.social_media_posts.find_or_initialize_by(platform: "internet_archive")
        post.update!(url: result[:ia_url]) if post.url.blank?
      end

      ActivityLog.create!(
        action: "completed",
        target: "archive",
        level: :info,
        description: "Successfully archived: #{archive_item.title || archive_item.url}"
      ) if defined?(ActivityLog)

      Rails.logger.info "[ArchiveUrlJob] Completed archiving: #{archive_item.url}"

    rescue => e
      archive_item.mark_failed!(e.message)

      Rails.logger.error "[ArchiveUrlJob] Failed to archive #{archive_item.url}: #{e.message}"

      raise # Re-raise for retry mechanism
    end
  end

  private

  def self.handle_discard(job, error)
    archive_item = ArchiveItem.find_by(id: job.arguments.first)
    archive_item&.mark_failed!(error.message)

    ActivityLog.create!(
      action: "failed",
      target: "archive",
      level: :error,
      description: "Failed to archive URL: #{archive_item&.url} - #{error.message}"
    ) if defined?(ActivityLog)
  end
end
