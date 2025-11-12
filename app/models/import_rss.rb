class ImportRss
  require "feedjira"
  require "cgi"
  require "open-uri"
  # include ActiveStorage::SetCurrent
  def initialize(url, import_images = false)
    @url = url
    @import_images = import_images ? true : false
    @error_message = nil
  end

  def import_data
    ActivityLog.create!(
      action: "initiated",
      target: "import",
      level: :info,
      description: "Start Import from: #{@url}, import images: #{@import_images}"
    )
    feed = Feedjira.parse(URI.open(@url).read)

    feed.entries.each do |item|
      # slug = item.title ? item.title.parameterize : item.published
      if item.url.nil?
        next
      end

      encoded_link = item.url
      decoded_link = CGI.unescape(encoded_link)
      title = (item.title || item.published).to_s
      slug = decoded_link.split("/").last
      content = ActionText::Content.new(item.content)
      # get all images in the content and download them and then add them to the article content
      doc = Nokogiri::HTML(content.to_s)


        # doc, content.attachables = import_images(doc) if @import_images
        if @import_images
          begin
            doc, attachables = import_images(doc, title)
            content.attachables.concat(attachables)
          rescue StandardError => e
            raise "Image import failed: #{e.message}"
          end
        end

      content = doc.to_html
      Article.create(status: :publish,
                    title: title,
                    content: content,
                    created_at: item.published,
                    slug: slug,
                    description: item.summary,
                    )
    end
    ActivityLog.create!(
      action: "completed",
      target: "import",
      level: :info,
      description: "Import successfully from: #{@url}, import images: #{@import_images}"
    )
    true
  rescue StandardError => e
    @error_message = e.message
    ActivityLog.create!(
      action: "failed",
      target: "import",
      level: :error,
      description: "Import failed from: #{@url}, import images: #{@import_images}, error: #{e.message}"
    )
    false
  end

  def import_images(doc, title)
    attachables = []
    doc.css("img").each do |img|
      src = img["src"]
      next unless src

      begin
        URI.open(src) do |io|
          blob = ActiveStorage::Blob.create_and_upload!(
            io: io,
            filename: "#{title.parameterize}-#{SecureRandom.hex(4)}.#{io.content_type.split("/").last}",
            content_type: io.content_type
          )
          attachables << blob

          # Update image URL in content
          attachment = ActionText::Attachment.from_attachable(blob)
          relative_url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
          attachment.node["url"] = relative_url
          
          # 确保SGID也是正确的
          correct_sgid = blob.to_sgid.to_s
          attachment.node["sgid"] = correct_sgid
          
          img.replace(attachment.node.to_html)
        end
      rescue StandardError => e
        raise "Failed to download image: #{src} #{e}"
      end
    end
    return doc, attachables
  end
  def error_message
    @error_message
  end
end
