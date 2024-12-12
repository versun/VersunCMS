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

  def static_file
    @setting = Setting.first
    file_name = params[:file_name]

    if Setting::STATIC_FILES.key?(file_name)
      content = @setting.static_files&.dig(file_name) || Setting::STATIC_FILES[file_name][:placeholder]
      render plain: content, content_type: "text/plain"
    else
      head :not_found
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
      :head_code,
      social_links: {},
      static_files: {}
    )
  end
end
