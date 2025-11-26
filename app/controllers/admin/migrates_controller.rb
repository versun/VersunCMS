require "zip"
require "json"
require "nokogiri"
require "uri"
require "net/http"

class Admin::MigratesController < Admin::BaseController
  include ActiveStorage::SetCurrent

  def index
    @activity_logs = ActivityLog.track_activity("export") + 
                     ActivityLog.track_activity("wordpress_export") + 
                     ActivityLog.track_activity("import") +
                     ActivityLog.track_activity("github_backup")
  end

  def create
    operation_type = params[:operation_type]

    case operation_type
    when "export"
      handle_export
    when "import"
      handle_import
    when "github_backup"
      handle_github_backup
    else
      redirect_to admin_migrates_path, alert: "Unsupported operation type"
    end
  rescue StandardError => e
    Rails.logger.error "Migrate error: #{e.message}"
    redirect_to admin_migrates_path, alert: "An unexpected error occurred: #{e.message}"
  end

  private

  def handle_export
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

    redirect_to admin_migrates_path
  end

  def handle_import
    if params[:url].present?
      # RSS导入
      ImportFromRssJob.perform_later(params[:url], params[:import_images])
      redirect_to admin_migrates_path, notice: "RSS Import in progress, please check the logs for details"
    elsif params[:zip_file].present?
      # ZIP文件导入
      import_from_zip
    else
      redirect_to admin_migrates_path, alert: "Please provide either RSS URL or ZIP file for import"
    end
  end

  def import_from_zip
    uploaded_file = params[:zip_file]

    # 验证文件类型
    unless uploaded_file.content_type == "application/zip" || uploaded_file.original_filename.end_with?(".zip")
      raise "Only ZIP files are allowed for import"
    end

    # 保存上传的文件到临时位置
    temp_file = Rails.root.join("tmp", "uploads", "import_#{Time.current.to_i}_#{File.basename(uploaded_file.original_filename)}")
    FileUtils.mkdir_p(File.dirname(temp_file))

    File.open(temp_file, "wb") do |f|
      IO.copy_stream(uploaded_file, f)
    end

    # 执行导入任务
    ImportFromZipJob.perform_later(temp_file.to_s)

    redirect_to admin_migrates_path, notice: "ZIP Import in progress, please check the logs for details"
  rescue StandardError => e
    Rails.logger.error "ZIP Import error: #{e.message}"
    redirect_to admin_migrates_path, alert: "ZIP import failed: #{e.message}"
  ensure
    # 清理临时文件将在job完成后进行
  end

  def handle_github_backup
    setting = Setting.first

    unless setting&.github_backup_enabled
      redirect_to admin_migrates_path, alert: "GitHub backup is not enabled. Please configure it in Settings first."
      return
    end

    unless setting.github_repo_url.present? && setting.github_token.present?
      redirect_to admin_migrates_path, alert: "GitHub backup is not configured properly. Please check your settings."
      return
    end

    GithubBackupJob.perform_later

    ActivityLog.create!(
      action: "initiated",
      target: "github_backup",
      level: "info",
      description: "GitHub Backup initiated"
    )

    redirect_to admin_migrates_path, notice: "GitHub backup initiated. Please check the logs for details."
  end
end
