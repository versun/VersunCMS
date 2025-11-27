class Admin::BackupsController < Admin::BaseController
  def show
    @setting = Setting.first || Setting.create!
    @activity_logs = ActivityLog.track_activity("github_backup")
  end

  def update
    @setting = Setting.first

    if @setting.update(backup_params)
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
