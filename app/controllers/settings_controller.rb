class SettingsController < ApplicationController
  def edit
    @setting = Setting.first_or_create
  end

  def update
    @setting = Setting.first
    if @setting.update(setting_params)
      refresh_settings
      redirect_to admin_path, notice: "Setting was successfully updated."
    else
      render :edit
    end
  end

  private

  def setting_params
    params.require(:setting).permit(
      :title,
      :description,
      :author,
      :url,
      :footer,
      :custom_css,
      :time_zone,
      social_links: {}
    )
  end
end
