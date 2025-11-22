class Admin::DownloadsController < Admin::BaseController
  def show
    filename = File.basename(params[:filename].to_s)

    # 安全检查：只允许下载特定目录下的文件
    safe_path = Rails.root.join("tmp", "exports", filename)

    # 验证文件是否存在且在我们的预期目录下
    unless safe_path.exist? || safe_path.file?
      flash[:alert] = "文件不存在"
      redirect_to admin_exports_path and return
    end

    # 验证文件路径确实在我们的tmp/exports目录下
    unless safe_path.to_s.start_with?(Rails.root.join("tmp", "exports").to_s)
      flash[:alert] = "不允许下载此文件"
      redirect_to admin_exports_path and return
    end

    # 发送文件
    send_file safe_path,
              filename: filename,
              type: "application/octet-stream",
              disposition: "attachment"
  rescue => e
    Rails.logger.error "Download error: #{e.message}"
    flash[:alert] = "下载失败: #{e.message}"
    redirect_to admin_exports_path
  end
end
