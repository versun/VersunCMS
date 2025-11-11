class Admin::ExportsController < Admin::BaseController
  # before_action :authenticate_user!
  skip_before_action :require_authentication, only: [:new, :create]  # 临时允许测试
  skip_before_action :verify_authenticity_token, only: [:create]  # 临时禁用CSRF验证

  def new
    @activity_logs = ActivityLog.track_activity("export")
  end

  def create
    ExportDataJob.perform_later
    ActivityLog.create!(
      action: 'started',
      target: 'export',
      level: 'info',
      description: "导出任务已启动，请稍后检查结果。"
    )
  end
end
