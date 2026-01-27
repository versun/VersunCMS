class Admin::EditorImagesController < Admin::BaseController
  def create
    uploaded_file = params[:file]

    unless uploaded_file
      return render json: { error: "No file provided" }, status: :bad_request
    end

    # Validate file type
    allowed_types = %w[image/jpeg image/png image/gif image/webp]
    unless allowed_types.include?(uploaded_file.content_type)
      return render json: { error: "Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed." }, status: :bad_request
    end

    # Create a unique filename
    extension = File.extname(uploaded_file.original_filename).downcase
    filename = "#{SecureRandom.uuid}#{extension}"

    # Store file using ActiveStorage
    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_file.to_io,
      filename: filename,
      content_type: uploaded_file.content_type,
      metadata: { custom: "tinymce_upload" }
    )

    # Generate the URL for the uploaded image
    # Use full URL (with host) to avoid path resolution issues in TinyMCE
    image_url = Rails.application.routes.url_helpers.rails_blob_url(blob, host: request.host_with_port)

    render json: { location: image_url }
  rescue => e
    Rails.logger.error "TinyMCE image upload failed: #{e.message}"
    render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error
  end
end
