class Admin::DownloadsController < Admin::BaseController
  EXPORTS_DIR = Rails.root.join("tmp", "exports").freeze

  def show
    # Sanitize filename by removing any path components
    filename = File.basename(params[:filename].to_s)

    # Reject empty or suspicious filenames
    if filename.blank? || filename.start_with?(".")
      flash[:alert] = "无效的文件名"
      redirect_to admin_migrates_path and return
    end

    # Construct the safe path
    safe_path = EXPORTS_DIR.join(filename)

    # Verify file exists and is a regular file
    unless safe_path.exist? && safe_path.file?
      flash[:alert] = "文件不存在"
      redirect_to admin_migrates_path and return
    end

    # Verify the resolved path is within the exports directory
    # This prevents symlink attacks
    begin
      real_path = safe_path.realpath
      exports_real_path = EXPORTS_DIR.realpath
      unless real_path.to_s.start_with?(exports_real_path.to_s + File::SEPARATOR) ||
             real_path.to_s == exports_real_path.to_s
        flash[:alert] = "不允许下载此文件"
        redirect_to admin_migrates_path and return
      end
    rescue Errno::ENOENT
      flash[:alert] = "文件不存在"
      redirect_to admin_migrates_path and return
    end

    # Send the file
    send_file safe_path,
              filename: filename,
              type: "application/octet-stream",
              disposition: "attachment"
  rescue => e
    Rails.event.notify(
      "admin.downloads_controller.download_error",
      level: "error",
      component: "Admin::DownloadsController",
      message: e.message,
      filename: params[:filename]
    )
    flash[:alert] = "下载失败: #{e.message}"
    redirect_to admin_migrates_path
  end
end
