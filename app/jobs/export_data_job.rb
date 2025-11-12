class ExportDataJob < ApplicationJob
  queue_as :default

  def perform
    exporter = Export.new
    success = exporter.generate

    if success
      # 将文件移动到tmp文件夹
      tmp_dir = Rails.root.join("tmp", "exports")
      FileUtils.mkdir_p(tmp_dir)

      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      new_filename = "versuncms_export_#{timestamp}.zip"
      tmp_path = File.join(tmp_dir, new_filename)

      # 移动文件到tmp目录
      FileUtils.mv(exporter.zip_path, tmp_path)

      # 创建下载URL（假设使用Rails的静态文件服务）
      download_url = "/tmp/exports/#{new_filename}"

      # 创建ActivityLog记录
      ActivityLog.create!(
        action: "completed",
        target: "export",
        level: "info",
        description: "数据导出完成:#{download_url}"
      )

      Rails.logger.info "Export completed successfully. File saved to: #{tmp_path}"
    else
      # 创建ActivityLog记录失败信息
      ActivityLog.create!(
        action: "failed",
        target: "export",
        level: "error",
        description: "数据导出失败:#{exporter.error_message}",
      )

      Rails.logger.error "Export failed: #{exporter.error_message}"
    end
  end
end
