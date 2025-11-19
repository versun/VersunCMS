class ExportWordpressJob < ApplicationJob
  queue_as :default

  def perform
    exporter = WordpressExport.new
    success = exporter.generate

    if success
      # 将文件移动到tmp文件夹
      tmp_dir = Rails.root.join("tmp", "exports")
      FileUtils.mkdir_p(tmp_dir)

      # 获取生成的文件路径
      exported_file = exporter.export_path
      
      if File.exist?(exported_file)
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        new_filename = exported_file.end_with?('.zip') ? 
          "versuncms_wordpress_export_#{timestamp}.zip" : 
          "versuncms_wordpress_export_#{timestamp}.xml"
        tmp_path = File.join(tmp_dir, new_filename)

        # 移动文件到tmp目录
        FileUtils.mv(exported_file, tmp_path)

        # 创建下载URL
        download_url = "/tmp/exports/#{new_filename}"

        # 创建ActivityLog记录
        ActivityLog.create!(
          action: "completed",
          target: "wordpress_export",
          level: "info",
          description: "WordPress导出完成: #{download_url}"
        )

        Rails.logger.info "WordPress export completed successfully. File saved to: #{tmp_path}"
      else
        handle_error("导出文件未生成")
      end
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
      description: "WordPress导出失败: #{error_message}"
    )
  end
end