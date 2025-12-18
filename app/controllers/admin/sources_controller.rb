class Admin::SourcesController < Admin::BaseController
  # POST /admin/sources/archive
  # Save a URL to Internet Archive
  def archive
    url = params[:url]

    if url.blank?
      render json: { error: "URL is required" }, status: :unprocessable_entity
      return
    end

    service = Integrations::InternetArchiveService.new
    result = service.save_url(url)

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: {
        success: true,
        archived_url: result[:archived_url]
      }
    end
  end
end
