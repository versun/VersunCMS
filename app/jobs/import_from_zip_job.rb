class ImportFromZipJob < ApplicationJob
  queue_as :default

  def perform(zip_path)
    importer = ImportZip.new(zip_path)
    success = importer.import_data

    if success
      # 创建ActivityLog记录
      ActivityLog.create!(
        action: "completed",
        target: "import",
        level: "info",
        description: "ZIP导入任务完成: #{File.basename(zip_path)}"
      )

      Rails.event.notify "import_from_zip_job.completed",
        level: "info",
        component: "ImportFromZipJob",
        zip_path: zip_path
    else
      # 创建ActivityLog记录失败信息
      ActivityLog.create!(
        action: "failed",
        target: "import",
        level: "error",
        description: "ZIP导入任务失败: #{importer.error_message}",
      )

      Rails.event.notify "import_from_zip_job.failed",
        level: "error",
        component: "ImportFromZipJob",
        error_message: importer.error_message
    end

    # 清理上传的临时文件
    if zip_path.include?("/tmp/uploads/") && File.exist?(zip_path)
      FileUtils.rm_f(zip_path)
      Rails.event.notify "import_from_zip_job.cleanup",
        level: "info",
        component: "ImportFromZipJob",
        zip_path: zip_path
    end
  end
end
