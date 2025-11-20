require "zip"
require "json"
require "nokogiri"
require "uri"
require "net/http"

class Admin::ImportsController < Admin::BaseController
  include ActiveStorage::SetCurrent

  def index
    @activity_logs = ActivityLog.track_activity("import")
  end

  def create
    if params[:url].present?
      # RSS导入
      ImportFromRssJob.perform_later(params[:url], params[:import_images])
      redirect_to admin_imports_path, notice: "RSS Import in progress, please check the logs for details"
    elsif params[:zip_file].present?
      # ZIP文件导入
      import_from_zip
    else
      redirect_to admin_imports_path, alert: "Please provide either RSS URL or ZIP file for import"
    end
  rescue StandardError => e
    Rails.logger.error "Import error: #{e.message}"
    redirect_to admin_imports_path, alert: "An unexpected error occurred during import: #{e.message}"
  end

  private

  def import_from_zip
    uploaded_file = params[:zip_file]

    # 验证文件类型
    unless uploaded_file.content_type == "application/zip" || uploaded_file.original_filename.end_with?(".zip")
      raise "Only ZIP files are allowed for import"
    end

    # 保存上传的文件到临时位置
    temp_file = Rails.root.join("tmp", "uploads", "import_#{Time.current.to_i}_#{uploaded_file.original_filename}")
    FileUtils.mkdir_p(File.dirname(temp_file))

    File.open(temp_file, "wb") do |f|
      IO.copy_stream(uploaded_file, f)
    end

    # 执行导入任务
    ImportFromZipJob.perform_later(temp_file.to_s)

    redirect_to admin_imports_path, notice: "ZIP Import in progress, please check the logs for details"
  rescue StandardError => e
    Rails.logger.error "ZIP Import error: #{e.message}"
    redirect_to admin_imports_path, alert: "ZIP import failed: #{e.message}"
  ensure
    # 清理临时文件将在job完成后进行
  end
end
