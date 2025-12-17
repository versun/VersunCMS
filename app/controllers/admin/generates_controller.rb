class Admin::GeneratesController < Admin::BaseController
  def edit
    @setting = Setting.first_or_create
  end

  def update
    @setting = Setting.first_or_create
    
    params_hash = generate_params
    # Ensure auto_regenerate_triggers is always an array (even if empty)
    params_hash[:auto_regenerate_triggers] ||= []
    
    if @setting.update(params_hash)
      ActivityLog.create!(
        action: "updated",
        target: "setting",
        level: :info,
        description: "更新生成设置"
      )
      redirect_to edit_admin_generate_path, notice: "生成设置已成功更新。"
    else
      ActivityLog.create!(
        action: "failed",
        target: "setting",
        level: :error,
        description: "更新生成设置失败: #{@setting.errors.full_messages.join(', ')}"
      )
      render :edit
    end
  end

  private

  def generate_params
    params.require(:setting).permit(:static_generation_destination, :github_repo_url, :github_token, :github_backup_branch, auto_regenerate_triggers: [])
  end
end
