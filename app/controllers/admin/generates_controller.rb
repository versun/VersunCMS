class Admin::GeneratesController < Admin::BaseController
  def edit
    @setting = Setting.first_or_create
    load_git_integrations
  end

  def update
    @setting = Setting.first_or_create

    params_hash = generate_params
    # Ensure auto_regenerate_triggers is always an array (even if empty)
    params_hash[:auto_regenerate_triggers] ||= []

    if @setting.update(params_hash)
      description = "更新生成设置"
      if params_hash[:deploy_provider] == "local" && params_hash[:local_generation_path].present?
        description += " - 本地路径: #{params_hash[:local_generation_path]}"
      elsif params_hash[:deploy_provider].present? && params_hash[:deploy_provider] != "local"
        description += " - #{params_hash[:deploy_provider]} 仓库: #{params_hash[:deploy_repo_url]}"
      end

      ActivityLog.create!(
        action: "updated",
        target: "setting",
        level: :info,
        description: description
      )
      redirect_to edit_admin_generate_path, notice: "生成设置已成功更新。"
    else
      ActivityLog.create!(
        action: "failed",
        target: "setting",
        level: :error,
        description: "更新生成设置失败: #{@setting.errors.full_messages.join(', ')}"
      )
      load_git_integrations
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_git_integrations
    GitIntegration.ensure_all_providers
    @git_integrations_by_provider = GitIntegration.all.index_by(&:provider)
  end

  def generate_params
    params.require(:setting).permit(
      :deploy_provider,
      :deploy_repo_url,
      :deploy_branch,
      :local_generation_path,
      :static_generation_delay,
      auto_regenerate_triggers: []
    )
  end
end
