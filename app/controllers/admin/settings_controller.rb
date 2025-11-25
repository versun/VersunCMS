class Admin::SettingsController < Admin::BaseController
  def edit
    @setting = Setting.first_or_create
    render "admin/settings/edit"
  end

  def update
    @setting = Setting.first
    if @setting.update(setting_params)
      refresh_settings
      redirect_to admin_root_path, notice: "Setting was successfully updated."
    else
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
