class Tools::BackupController < ApplicationController
  # before_action :authenticate_user!

  def index
    @backup_setting = BackupSetting.first_or_initialize
    @backup_logs = BackupLog.order(created_at: :desc).limit(10)
  end

  def create
    @backup_setting = BackupSetting.first_or_initialize

    # Generate SSH key pair if not present
    if @backup_setting.ssh_public_key.blank? || @backup_setting.ssh_private_key.blank?
      key_pair = BackupSetting.generate_ssh_key_pair
      params[:backup_setting][:ssh_public_key] = key_pair[:public_key]
      params[:backup_setting][:ssh_private_key] = key_pair[:private_key]
    end

    if @backup_setting.update(backup_params)
      redirect_to tools_backup_index_path, notice: "Backup settings saved successfully."
    else
      render :index
    end
  end

  def update
    @backup_setting = BackupSetting.first_or_initialize

    # Generate SSH key pair if not present
    if @backup_setting.ssh_public_key.blank? || @backup_setting.ssh_private_key.blank?
      key_pair = BackupSetting.generate_ssh_key_pair
      params[:backup_setting][:ssh_public_key] = key_pair[:public_key]
      params[:backup_setting][:ssh_private_key] = key_pair[:private_key]
    end

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
    render json: {
      last_backup: BackupLog.last&.created_at,
      status: BackupLog.last&.status,
      message: BackupLog.last&.message
    }
  end

  def regenerate_ssh_key
    @backup_setting = BackupSetting.first_or_initialize
    key_pair = BackupSetting.generate_ssh_key_pair

    if @backup_setting.update(
      ssh_public_key: key_pair[:public_key],
      ssh_private_key: key_pair[:private_key]
    )
      redirect_to tools_backup_index_path, notice: "SSH key pair regenerated successfully."
    else
      redirect_to tools_backup_index_path, alert: "Failed to regenerate SSH key pair."
    end
  end

  private

  def backup_params
    params.require(:backup_setting).permit(
      :repository_url,
      :branch_name,
      :git_name,
      :git_email,
      :auto_backup,
      :backup_interval,
      :ssh_public_key,
      :ssh_private_key
    )
  end
end
