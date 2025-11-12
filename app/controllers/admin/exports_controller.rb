class Admin::ExportsController < Admin::BaseController
  def index
    @activity_logs = ActivityLog.track_activity("export")
  end

  def create
    ExportDataJob.perform_later
    ActivityLog.create!(
      action: 'initiated',
      target: 'export',
      level: 'info',
      description: "导出任务已启动，请稍后检查结果。"
    )
  end
end
