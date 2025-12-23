module StaticGeneration
  class BlobExporter
    def initialize(uploads_dir:, event: Rails.event)
      @uploads_dir = uploads_dir
      @event = event
      @exported_blobs = {}
    end

    def exported_count
      @exported_blobs.size
    end

    def export_from_rich_text(rich_text)
      return unless rich_text&.body&.attachments

      rich_text.body.attachments.each do |attachment|
        next unless attachment.attachable.is_a?(ActiveStorage::Blob)

        export_blob(attachment.attachable)
      end
    end

    def static_path_for_signed_id(signed_id, original: nil)
      blob = ActiveStorage::Blob.find_signed(signed_id)
      return original if blob.blank?

      @exported_blobs[blob.id] || export_blob(blob) || original
    rescue => e
      @event.notify("static_generator.blob_resolve_failed", level: "warn", component: "StaticGenerator", error: e.message)
      original
    end

    def export_blob(blob, force: false)
      return @exported_blobs[blob.id] if @exported_blobs[blob.id] && !force

      filename = "#{blob.id}-#{blob.filename}"
      output_path = @uploads_dir.join(filename)
      FileUtils.mkdir_p(@uploads_dir)

      begin
        if blob.image? && blob.variable?
          variant = blob.variant(
            resize_to_limit: [ 1200, 1200 ],
            saver: {
              quality: 85,
              strip: true
            }
          )

          File.binwrite(output_path, variant.processed.download)
        else
          blob.open do |file|
            FileUtils.cp(file.path, output_path)
          end
        end

        static_path = "/uploads/#{filename}"
        @exported_blobs[blob.id] = static_path

        original_size = blob.byte_size
        compressed_size = File.size(output_path)
        compression_ratio = if original_size.to_i.positive?
          ((1 - compressed_size.to_f / original_size) * 100).round(1)
        end

        @event.notify(
          "static_generator.image_exported",
          level: "debug",
          component: "StaticGenerator",
          content_type: blob.content_type,
          path: static_path,
          compression_ratio: compression_ratio
        )

        static_path
      rescue => e
        @event.notify("static_generator.blob_export_failed", level: "error", component: "StaticGenerator", blob_id: blob.id, error: e.message)

        begin
          blob.open do |file|
            FileUtils.cp(file.path, output_path)
          end

          static_path = "/uploads/#{filename}"
          @exported_blobs[blob.id] = static_path
          @event.notify("static_generator.original_image_exported", level: "warn", component: "StaticGenerator", path: static_path)
          static_path
        rescue => fallback_error
          @event.notify("static_generator.fallback_export_failed", level: "error", component: "StaticGenerator", error: fallback_error.message)
          nil
        end
      end
    end
  end
end
