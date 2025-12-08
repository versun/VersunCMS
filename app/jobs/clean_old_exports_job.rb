class CleanOldExportsJob < ApplicationJob
  queue_as :default

  # 执行清理旧导出和导入文件的任务
  # @param options [Hash] 选项哈希，包含 :days 键（保留最近多少天的文件，默认7天）
  #   SolidQueue 会传递哈希作为位置参数，例如 { days: 7 }
  def perform(options = {})
    days = if options.is_a?(Hash)
             options[:days] || options["days"] || 7
           else
             7
           end
    Rails.logger.info "Starting cleanup of old export/import files (keeping files newer than #{days} days)..."

    result = Export.cleanup_old_exports(days: days)

    # 创建ActivityLog记录
    ActivityLog.create!(
      action: result[:errors] > 0 ? "warning" : "completed",
      target: "export_import_cleanup",
      level: result[:errors] > 0 ? "warning" : "info",
      description: result[:message]
    )

    Rails.logger.info result[:message]
    result
  end
end
