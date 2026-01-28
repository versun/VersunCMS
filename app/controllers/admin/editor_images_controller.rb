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
      content_type: uploaded_file.content_type
    )

    # Generate a permanent URL that never expires
    # Using rails_blob_url which redirects to actual storage
    # This URL is permanent - it uses signed_id but only for lookup, not expiration
    image_url = Rails.application.routes.url_helpers.rails_blob_url(
      blob,
      host: request.host,
      port: request.port != 80 && request.port != 443 ? request.port : nil,
      protocol: request.protocol
    )

    render json: { location: image_url }
  rescue => e
    Rails.logger.error "TinyMCE image upload failed: #{e.message}"
    render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error
  end
end
