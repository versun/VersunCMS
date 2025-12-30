class Admin::ArchivesController < Admin::BaseController
  def index
    @archive_setting = ArchiveSetting.instance
    @archive_items = ArchiveItem.recent.paginate(page: params[:page], per_page: 25)
    @git_integrations = GitIntegration.enabled
  end

  def update_settings
    @archive_setting = ArchiveSetting.instance

    if @archive_setting.update(archive_setting_params)
      ActivityLog.create!(
        action: "updated",
        target: "archive_setting",
        level: :info,
        description: "更新归档设置"
      )
      redirect_to admin_archives_path, notice: "归档设置已更新。"
    else
      @archive_items = ArchiveItem.recent.paginate(page: params[:page], per_page: 25)
      @git_integrations = GitIntegration.enabled
      flash.now[:alert] = @archive_setting.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def create
    url = params[:url].to_s.strip
    title = params[:title].to_s.strip.presence

    if url.blank?
      redirect_to admin_archives_path, alert: "URL 不能为空"
      return
    end

    normalized_url = ArchiveItem.normalize_url(url)
    archive_item = ArchiveItem.find_or_initialize_by(url: normalized_url)

    if archive_item.completed?
      redirect_to admin_archives_path, alert: "该 URL 已归档"
      return
    end

    archive_item.title = title if title
    archive_item.status = :pending

    if archive_item.save
      ArchiveUrlJob.perform_later(archive_item.id)

      ActivityLog.create!(
        action: "queued",
        target: "archive",
        level: :info,
        description: "已将 URL 加入归档队列: #{archive_item.url}"
      )

      redirect_to admin_archives_path, notice: "URL 已加入归档队列"
    else
      redirect_to admin_archives_path, alert: archive_item.errors.full_messages.join(", ")
    end
  end

  def retry
    @archive_item = ArchiveItem.find(params[:id])

    if @archive_item.failed?
      @archive_item.update!(status: :pending, error_message: nil)
      ArchiveUrlJob.perform_later(@archive_item.id)

      redirect_to admin_archives_path, notice: "已重新加入队列: #{@archive_item.url}"
    else
      redirect_to admin_archives_path, alert: "只能重试失败的归档项目"
    end
  end

  def destroy
    @archive_item = ArchiveItem.find(params[:id])
    @archive_item.destroy!

    ActivityLog.create!(
      action: "deleted",
      target: "archive",
      level: :info,
      description: "删除归档项目: #{@archive_item.url}"
    )

    redirect_to admin_archives_path, notice: "归档项目已删除"
  end

  def verify_ia
    @archive_setting = ArchiveSetting.instance
    @message = ""
    @status = ""
    @target = "verify-ia-status"

    ia_service = InternetArchiveService.new

    unless ia_service.configured?
      @status = "error"
      @message = "Internet Archive 凭据未配置"
      return respond_verification
    end

    ia_result = ia_service.verify
    if ia_result[:error]
      @status = "error"
      @message = "验证失败: #{ia_result[:error]}"
    else
      @status = "success"
      @message = "S3 凭据验证成功！"
    end

    respond_verification
  end

  private

  def archive_setting_params
    params.require(:archive_setting).permit(
      :git_integration_id,
      :repo_url,
      :branch,
      :auto_archive_published_articles,
      :auto_archive_article_links,
      :auto_submit_to_archive_org,
      :ia_access_key,
      :ia_secret_key,
      :enabled
    )
  end

  def respond_verification
    respond_to do |format|
      format.turbo_stream { render :verify }
      format.json { render json: { status: @status, message: @message } }
    end
  end
end
