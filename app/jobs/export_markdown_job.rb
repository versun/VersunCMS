class ExportMarkdownJob < ApplicationJob
  queue_as :default

  def perform
    exporter = MarkdownExport.new
    success = exporter.generate

    if success
      download_url = exporter.zip_path

      ActivityLog.log!(
        action: :completed,
        target: :export,
        level: :info,
        format: "markdown",
        file: download_url
      )

      Rails.event.notify "export_markdown_job.completed",
        level: "info",
        component: "ExportMarkdownJob",
        download_url: download_url
    else
      ActivityLog.log!(
        action: :failed,
        target: :export,
        level: :error,
        format: "markdown",
        error: exporter.error_message
      )

      Rails.event.notify "export_markdown_job.failed",
        level: "error",
        component: "ExportMarkdownJob",
        error_message: exporter.error_message
    end
  end
end
