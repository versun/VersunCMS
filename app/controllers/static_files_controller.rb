class StaticFilesController < ApplicationController
  allow_unauthenticated_access
  def show
    # params[:filename] is an array from wildcard route, join it back to string
    filename = params[:filename].is_a?(Array) ? params[:filename].join('/') : params[:filename]
    
    # Find by StaticFile filename
    static_file = StaticFile.find_by(filename: filename)

    if static_file&.file&.attached?
      # 重定向到 Active Storage 的服务 URL
      redirect_to rails_blob_path(static_file.file), allow_other_host: true
    else
      head :not_found
    end
  end
end
