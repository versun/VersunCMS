class ExportWordpressJob < ApplicationJob
  queue_as :default

  def perform
    exporter = WordpressExport.new
    success = exporter.generate

    if success
      # 创建下载URL
      download_url = exporter.export_path

      # 创建ActivityLog记录
      ActivityLog.create!(
        action: "completed",
        target: "wordpress_export",
        level: "info",
        description: "WordPress Export Completed: #{download_url}"
      )

      Rails.logger.info "WordPress export completed successfully. File saved to: #{download_url}"
    else
      handle_error(exporter.error_message)
    end
  rescue => e
    handle_error(e.message)
    Rails.logger.error "WordPress export job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def handle_error(error_message)
    ActivityLog.create!(
      action: "failed",
      target: "wordpress_export",
      level: "error",
      description: "WordPress Export Failed: #{error_message}"
    )
  end
end
