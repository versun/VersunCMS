class ExportMarkdownJob < ApplicationJob
  queue_as :default

  def perform
    exporter = MarkdownExport.new
    success = exporter.generate

    if success
      download_url = exporter.zip_path

      ActivityLog.create!(
        action: "completed",
        target: "markdown_export",
        level: "info",
        description: "Markdown Export Finished:#{download_url}"
      )

      Rails.event.notify "export_markdown_job.completed",
        level: "info",
        component: "ExportMarkdownJob",
        download_url: download_url
    else
      ActivityLog.create!(
        action: "failed",
        target: "markdown_export",
        level: "error",
        description: "Markdown Export Failed:#{exporter.error_message}",
      )

      Rails.event.notify "export_markdown_job.failed",
        level: "error",
        component: "ExportMarkdownJob",
        error_message: exporter.error_message
    end
  end
end
