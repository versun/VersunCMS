class SettingsController < ApplicationController
  def edit
    @setting = Setting.first_or_create
    @files = Dir.glob(Rails.public_path.join("*")).map { |f| File.basename(f) }
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

  def upload
    if params[:file]
      FileUtils.mkdir_p(Rails.public_path)
      File.binwrite(Rails.public_path.join(params[:file].original_filename), params[:file].read)
      redirect_to edit_setting_path, notice: "File uploaded successfully"
    else
      redirect_to edit_setting_path, alert: "No file selected"
    end
  end

  def destroy
    file_path = Rails.public_path.join(params[:filename].to_s)

    if File.exist?(file_path)
      File.delete(file_path)
      redirect_to edit_setting_path, notice: "File deleted successfully, please refresh the app to apply changes"
    else
      redirect_to edit_setting_path, alert: "File not found"
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
                            :file,
                            :tool_code,
                            social_links: {},
                            static_files: {} ])
  end
end
