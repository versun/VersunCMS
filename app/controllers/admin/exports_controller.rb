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
        description: "WordPress Export Initiated"
      )
      flash[:notice] = "WordPress Export Initiated"
    when "default"
      ExportDataJob.perform_later
      ActivityLog.create!(
        action: "initiated",
        target: "export",
        level: "info",
        description: "Export Initiated"
      )
      flash[:notice] = "Export Initiated"
    else
      flash[:alert] = "Unsupported export type"
    end

    redirect_to admin_exports_path
  end
end
