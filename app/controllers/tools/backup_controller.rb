class Tools::BackupController < ApplicationController
  # before_action :authenticate_user!

  def index
    @backup_setting = BackupSetting.instance
    @activity_logs = ActivityLog.track_activity("backup")
  end

  def create
    @backup_setting = BackupSetting.instance

    if @backup_setting.update(backup_params)
      redirect_to tools_backup_index_path, notice: "Backup settings saved successfully."
    else
      render :index
    end
  end

  def update
    @backup_setting = BackupSetting.instance

    if @backup_setting.update(backup_params)
      redirect_to tools_backup_index_path, notice: "Backup settings saved successfully."
    else
      render :index
    end
  end

  def perform_backup
    BackupJob.perform_later
    redirect_to tools_backup_index_path, notice: "Backup process started."
  end

  def backup_status
    render json: BackupSetting.instance.last_backup_status
  end

  def list_backups
    @backups = BackupSetting.instance.list_backups
    render json: @backups
  end

  def restore
    backup_key = params[:backup_key]
    success = BackupSetting.instance.restore_backup(backup_key)

    if success
      redirect_to tools_backup_index_path, notice: "Database restored successfully from backup."
    else
      redirect_to tools_backup_index_path, alert: "Failed to restore database from backup."
    end
  end

  private

  def backup_params
    params.require(:backup_setting).permit(
      :s3_bucket,
      :s3_region,
      :s3_access_key_id,
      :s3_secret_access_key,
      :s3_endpoint,
      :s3_prefix,
      :s3_enabled,
      :auto_backup,
      :backup_interval_hours,
      :backup_retention_days
    )
  end
end
