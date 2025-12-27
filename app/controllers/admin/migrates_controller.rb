class Admin::MigratesController < Admin::BaseController
  include ActiveStorage::SetCurrent

  def index
  end

  def create
    operation_type = params[:operation_type]

    case operation_type
    when "export"
      handle_export
    when "import"
      handle_import
    else
      redirect_to admin_migrates_path, alert: "Unsupported operation type"
    end
  rescue StandardError => e
    Rails.event.notify(
      "admin.migrates_controller.operation_error",
      level: "error",
      component: "Admin::MigratesController",
      operation_type: params[:operation_type],
      message: e.message
    )
    redirect_to admin_migrates_path, alert: "An unexpected error occurred: #{e.message}"
  end

  private

  def handle_export
    export_type = (params[:export_type].presence || "default").to_s

    export_config = {
      "default" => { job: ExportDataJob, target: "export", description: "Export Initiated" },
      "markdown" => { job: ExportMarkdownJob, target: "markdown_export", description: "Markdown Export Initiated" }
    }.fetch(export_type, nil)

    unless export_config
      redirect_to admin_migrates_path, alert: "Unsupported export type" and return
    end

    export_config[:job].perform_later
    ActivityLog.create!(
      action: "initiated",
      target: export_config[:target],
      level: "info",
      description: export_config[:description]
    )
    flash[:notice] = export_config[:description]

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

    # Validate file type
    unless uploaded_file.content_type == "application/zip" || uploaded_file.original_filename.to_s.end_with?(".zip")
      raise "Only ZIP files are allowed for import"
    end

    # Generate a secure temporary filename using SecureRandom to avoid
    # any potential issues with user-provided filenames
    secure_filename = "import_#{Time.current.to_i}_#{SecureRandom.hex(8)}.zip"
    uploads_dir = Rails.root.join("tmp", "uploads")
    FileUtils.mkdir_p(uploads_dir)

    temp_file = uploads_dir.join(secure_filename)

    File.open(temp_file, "wb") do |f|
      IO.copy_stream(uploaded_file, f)
    end

    # Execute import job
    ImportFromZipJob.perform_later(temp_file.to_s)

    redirect_to admin_migrates_path, notice: "ZIP Import in progress, please check the logs for details"
  rescue StandardError => e
    Rails.event.notify(
      "admin.migrates_controller.zip_import_error",
      level: "error",
      component: "Admin::MigratesController",
      message: e.message,
      filename: uploaded_file&.original_filename
    )
    redirect_to admin_migrates_path, alert: "ZIP import failed: #{e.message}"
  ensure
    # 清理临时文件将在job完成后进行
  end
end
