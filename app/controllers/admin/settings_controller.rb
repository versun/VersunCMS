class Admin::SettingsController < Admin::BaseController
  def edit
    @setting = Setting.first_or_create
    render "admin/settings/edit"
  end

  def update
    @setting = Setting.first
    if @setting.update(setting_params)
      ActivityLog.create!(
        action: "updated",
        target: "setting",
        level: :info,
        description: "更新站点设置"
      )
      refresh_settings
      redirect_to admin_root_path, notice: "Setting was successfully updated."
    else
      ActivityLog.create!(
        action: "failed",
        target: "setting",
        level: :error,
        description: "更新站点设置失败: #{@setting.errors.full_messages.join(', ')}"
      )
      render :edit
    end
  end



  private

  def setting_params
    params.expect(setting: [ :title,
                            :description,
                            :author,
                            :url,
                            :footer,
                            :custom_css,
                            :time_zone,
                            :head_code,
                            :giscus,
                            :tool_code,
                            :social_links_json,
                            social_links: {} ])
  end
end
