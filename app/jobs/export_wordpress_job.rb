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

      Rails.event.notify "export_wordpress_job.completed",
        level: "info",
        component: "ExportWordpressJob",
        download_url: download_url
    else
      handle_error(exporter.error_message)
    end
  rescue => e
    handle_error(e.message)
    Rails.event.notify "export_wordpress_job.failed",
      level: "error",
      component: "ExportWordpressJob",
      error_message: e.message
    Rails.event.notify "export_wordpress_job.error_backtrace",
      level: "error",
      component: "ExportWordpressJob",
      backtrace: e.backtrace.join("\n")
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
