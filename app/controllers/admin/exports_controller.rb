class Admin::ExportsController < Admin::BaseController
  def index
    @activity_logs = ActivityLog.track_activity("export") + ActivityLog.track_activity("wordpress_export")
  end

  def create
    export_type = params[:export_type] || "default"

    case export_type
    when "wordpress"
      ExportWordpressJob.perform_later
      ActivityLog.create!(
        action: "initiated",
        target: "wordpress_export",
        level: "info",
        description: "WordPress导出任务已启动，请稍后检查结果。"
      )
      flash[:notice] = "WordPress导出任务已启动，请稍后检查结果。"
    when "default"
      ExportDataJob.perform_later
      ActivityLog.create!(
        action: "initiated",
        target: "export",
        level: "info",
        description: "数据导出任务已启动，请稍后检查结果。"
      )
      flash[:notice] = "数据导出任务已启动，请稍后检查结果。"
    else
      flash[:alert] = "不支持的导出类型"
    end

    redirect_to admin_exports_path
  end
end
