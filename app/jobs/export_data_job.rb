class ExportDataJob < ApplicationJob
  queue_as :default

  def perform
    exporter = Export.new
    success = exporter.generate

    if success
      # 创建下载URL（使用Rails的静态文件服务）
      download_url = exporter.zip_path

      # 创建ActivityLog记录
      ActivityLog.log!(
        action: :completed,
        target: :export,
        level: :info,
        format: "default",
        file: download_url
      )

      Rails.event.notify "export_data_job.completed",
        level: "info",
        component: "ExportDataJob",
        download_url: download_url
    else
      # 创建ActivityLog记录失败信息
      ActivityLog.log!(
        action: :failed,
        target: :export,
        level: :error,
        format: "default",
        error: exporter.error_message
      )

      Rails.event.notify "export_data_job.failed",
        level: "error",
        component: "ExportDataJob",
        error_message: exporter.error_message
    end
  end
end
