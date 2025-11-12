class ImportFromZipJob < ApplicationJob
  queue_as :default

  def perform(zip_path)
    importer = ImportZip.new(zip_path)
    success = importer.import_data

    if success
      # 创建ActivityLog记录
      ActivityLog.create!(
        action: 'completed',
        target: 'import',
        level: 'info',
        description: "ZIP导入任务完成: #{File.basename(zip_path)}"
      )

      Rails.logger.info "ZIP import completed successfully. File: #{zip_path}"
    else
      # 创建ActivityLog记录失败信息
      ActivityLog.create!(
        action: 'failed',
        target: 'import',
        level: 'error',
        description: "ZIP导入任务失败: #{importer.error_message}",
      )

      Rails.logger.error "ZIP import failed: #{importer.error_message}"
    end

    # 清理上传的临时文件
    if zip_path.include?('/tmp/uploads/') && File.exist?(zip_path)
      FileUtils.rm_f(zip_path)
      Rails.logger.info "Cleaned up temporary upload file: #{zip_path}"
    end
  end
end
