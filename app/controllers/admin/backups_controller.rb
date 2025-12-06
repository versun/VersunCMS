class Admin::BackupsController < Admin::BaseController
  def show
    @setting = Setting.first || Setting.create!
  end

  def update
    @setting = Setting.first
    params_hash = backup_params.to_h

    # 如果 token 字段为空，保留原有值
    if params_hash[:github_token].blank? && @setting.github_token.present?
      params_hash[:github_token] = @setting.github_token
    end

    if @setting.update(params_hash)
      # Update the scheduled job when backup settings are saved
      ScheduledGithubBackupJob.update_schedule
      redirect_to admin_backups_path, notice: "Backup settings saved successfully"
    else
      render :show, alert: "Failed to save backup settings"
    end
  end

  def create
    setting = Setting.first

    unless setting&.github_backup_enabled
      redirect_to admin_backups_path, alert: "GitHub backup is not enabled. Please configure it in Settings first."
      return
    end

    unless setting.github_repo_url.present? && setting.github_token.present?
      redirect_to admin_backups_path, alert: "GitHub backup is not configured properly. Please check your settings."
      return
    end

    GithubBackupJob.perform_later

    ActivityLog.create!(
      action: "initiated",
      target: "github_backup",
      level: "info",
      description: "GitHub Backup initiated"
    )

    redirect_to admin_backups_path, notice: "GitHub backup initiated. Please check the activity history for details."
  end

  private

  def backup_params
    params.require(:setting).permit(
      :github_backup_enabled,
      :github_repo_url,
      :github_token,
      :github_backup_branch,
      :github_backup_cron,
      :git_user_name,
      :git_user_email
    )
  end
end
